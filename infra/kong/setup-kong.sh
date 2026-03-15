#!/bin/sh
# =============================================================================
# Kong Setup — Configura Services, Routes, Plugin JWT e Consumer
# =============================================================================
# Este script roda UMA vez após o Kong estar pronto.
# Usa a Admin API (porta 8001) para registrar:
#   1. Service + Route para Auth (/api/auth/*)
#   2. Service + Route para Manager (/api/videos/*)
#   3. Plugin JWT na rota do Manager
#   4. Consumer + JWT Credential para validação dos tokens
#
# VARIÁVEIS ESPERADAS (vêm do docker-compose via .env):
#   KONG_ADMIN_URL  — URL da Admin API do Kong (ex: http://kong:8001)
#   JWT_SECRET      — Segredo JWT (mesmo do Auth Service)
#   JWT_ISSUER      — Issuer do JWT (ex: fiapx-auth)
# =============================================================================

set -e

KONG_ADMIN=${KONG_ADMIN_URL:-http://kong:8001}

echo "================================================="
echo " KONG SETUP — Iniciando configuração"
echo "================================================="
echo ""

# Aguarda o Kong estar pronto
echo "[1/7] Aguardando Kong ficar disponível..."
for i in $(seq 1 30); do
  if wget -qO- "${KONG_ADMIN}/status" > /dev/null 2>&1; then
    echo "       Kong está pronto!"
    break
  fi
  echo "       Tentativa $i/30 — aguardando..."
  sleep 2
done

# Verifica se o Kong respondeu
if ! wget -qO- "${KONG_ADMIN}/status" > /dev/null 2>&1; then
  echo "ERRO: Kong não respondeu após 60 segundos. Abortando."
  exit 1
fi

# ─── 1. Service: Auth ─────────────────────────────────
echo ""
echo "[2/7] Registrando Service: auth-service → http://auth:3001"
wget -qO- --post-data \
  "name=auth-service&url=http://auth:3001" \
  "${KONG_ADMIN}/services/" 2>/dev/null || \
  echo "       (Service auth-service já existe — OK)"

# ─── 2. Route: Auth ───────────────────────────────────
echo ""
echo "[3/7] Registrando Route: /api/auth → auth-service"
wget -qO- --post-data \
  "name=auth-route&paths[]=/api/auth&strip_path=true&protocols[]=http&protocols[]=https" \
  "${KONG_ADMIN}/services/auth-service/routes" 2>/dev/null || \
  echo "       (Route auth-route já existe — OK)"

# ─── 3. Service: Manager ─────────────────────────────
echo ""
echo "[4/7] Registrando Service: manager-service → http://manager:3002"
wget -qO- --post-data \
  "name=manager-service&url=http://manager:3002" \
  "${KONG_ADMIN}/services/" 2>/dev/null || \
  echo "       (Service manager-service já existe — OK)"

# ─── 4. Route: Manager ───────────────────────────────
echo ""
echo "[5/7] Registrando Route: /api/videos → manager-service (Protegido)"
wget -qO- --post-data \
  "name=manager-route&paths[]=/api/videos&strip_path=true&protocols[]=http&protocols[]=https" \
  "${KONG_ADMIN}/services/manager-service/routes" 2>/dev/null || \
  echo "       (Route manager-route já existe — OK)"

# ─── 4.5 Route Publica: Manager Docs ───────────────────────────────
echo ""
echo "[5.5/7] Registrando Route: /manager-docs → manager-service (Publico p/ Swagger)"
wget -qO- --post-data \
  "name=manager-docs-route&paths[]=/manager-docs&strip_path=true&protocols[]=http&protocols[]=https" \
  "${KONG_ADMIN}/services/manager-service/routes" 2>/dev/null || \
  echo "       (Route manager-docs-route já existe — OK)"

# ─── 5. Plugin JWT no Manager ────────────────────────
echo ""
echo "[6/7] Habilitando plugin JWT na rota do Manager"
wget -qO- --post-data \
  "name=jwt&config.claims_to_verify=exp" \
  "${KONG_ADMIN}/routes/manager-route/plugins" 2>/dev/null || \
  echo "       (Plugin JWT já habilitado — OK)"

# ─── 6. Consumer + JWT Credential ────────────────────
echo ""
echo "[7/7] Criando Consumer e JWT Credential"

# Cria o consumer
wget -qO- --post-data \
  "username=fiapx-user" \
  "${KONG_ADMIN}/consumers/" 2>/dev/null || \
  echo "       (Consumer fiapx-user já existe — OK)"

# Cria a JWT credential com o mesmo secret e issuer do Auth Service
wget -qO- --post-data \
  "key=${JWT_ISSUER}&secret=${JWT_SECRET}&algorithm=HS256" \
  "${KONG_ADMIN}/consumers/fiapx-user/jwt" 2>/dev/null || \
  echo "       (JWT Credential já existe — OK)"

echo ""
echo "================================================="
echo " KONG SETUP — Configuração concluída!"
echo "================================================="
echo ""
echo " Rotas configuradas:"
echo "   → http://kong:8000/api/auth/*    → auth:3001  (aberta)"
echo "   → http://kong:8000/api/videos/*  → manager:3002  (protegida por JWT)"
echo ""
echo " Para testar:"
echo "   1. POST http://localhost:8000/api/auth/register"
echo "   2. POST http://localhost:8000/api/auth/login → pega o token"
echo "   3. GET  http://localhost:8000/api/videos (com Authorization: Bearer <token>)"
echo "================================================="
