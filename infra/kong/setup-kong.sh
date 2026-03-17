#!/bin/sh
# =============================================================================
# Kong Setup — Configura Services, Routes, Plugin JWT e Consumer
# =============================================================================
# Este script roda UMA vez após o Kong estar pronto.
# =============================================================================

set -e

# Instala curl se necessário
if ! command -v curl > /dev/null; then
  echo "Instalando curl..."
  apk add --no-cache curl > /dev/null
fi

KONG_ADMIN=${KONG_ADMIN_URL:-http://kong:8001}

echo "================================================="
echo " KONG SETUP — Iniciando configuração (CURL MODE)"
echo "================================================="
echo ""

# Aguarda o Kong estar pronto
echo "[1/7] Aguardando Kong ficar disponível..."
for i in $(seq 1 30); do
  if curl -s "${KONG_ADMIN}/status" > /dev/null; then
    echo "       Kong está pronto!"
    break
  fi
  echo "       Tentativa $i/30 — aguardando..."
  sleep 2
done

# ─── 1. Service: Auth ─────────────────────────────────
echo ""
echo "[2/7] Registrando/Atualizando Service: auth-service → http://auth:3001/auth"
curl -s -X POST "${KONG_ADMIN}/services/" \
  -d name=auth-service \
  -d url=http://auth:3001/auth > /dev/null || \
curl -s -X PATCH "${KONG_ADMIN}/services/auth-service" \
  -d url=http://auth:3001/auth > /dev/null

# ─── 2. Route: Auth ───────────────────────────────────
echo ""
echo "[3/7] Registrando Route: /auth → auth-service"
curl -s -X DELETE "${KONG_ADMIN}/routes/auth-route" > /dev/null 2>&1 || true
curl -s -X POST "${KONG_ADMIN}/services/auth-service/routes" \
  -d name=auth-route \
  -d "paths[]=/auth" \
  -d strip_path=true \
  -d "protocols[]=http" \
  -d "protocols[]=https" > /dev/null

# ─── 3. Service: Manager ─────────────────────────────
echo ""
echo "[4/7] Registrando/Atualizando Service: manager-service → http://manager:3002/videos"
curl -s -X POST "${KONG_ADMIN}/services/" \
  -d name=manager-service \
  -d url=http://manager:3002/videos > /dev/null || \
curl -s -X PATCH "${KONG_ADMIN}/services/manager-service" \
  -d url=http://manager:3002/videos > /dev/null

# ─── 4. Route: Manager ───────────────────────────────
echo ""
echo "[5/7] Registrando Route: /videos → manager-service (Protegido)"
curl -s -X DELETE "${KONG_ADMIN}/routes/manager-route" > /dev/null 2>&1 || true
curl -s -X POST "${KONG_ADMIN}/services/manager-service/routes" \
  -d name=manager-route \
  -d "paths[]=/videos" \
  -d strip_path=true \
  -d "protocols[]=http" \
  -d "protocols[]=https" > /dev/null


# ─── 4.5 Route Publica: Manager Docs ───────────────────────────────
echo ""
echo "[5.5/7] Registrando Route: /manager-docs → manager-service"
curl -s -X DELETE "${KONG_ADMIN}/routes/manager-docs-route" > /dev/null 2>&1 || true
curl -s -X POST "${KONG_ADMIN}/services/manager-service/routes" \
  -d name=manager-docs-route \
  -d "paths[]=/manager-docs" \
  -d strip_path=true \
  -d "protocols[]=http" \
  -d "protocols[]=https" > /dev/null

# ─── 5. Plugin JWT no Manager ────────────────────────
echo ""
echo "[6/7] Habilitando plugin JWT na rota do Manager"
curl -s -X POST "${KONG_ADMIN}/routes/manager-route/plugins" \
  -d name=jwt \
  -d "config.claims_to_verify=exp" > /dev/null || echo "       (Plugin JWT existente)"

# ─── 6. Consumer + JWT Credential ────────────────────
echo ""
echo "[7/7] Criando Consumer e JWT Credential"
curl -s -X POST "${KONG_ADMIN}/consumers/" \
  -d username=fiapx-user > /dev/null || echo "       (Consumer existente)"

curl -s -X POST "${KONG_ADMIN}/consumers/fiapx-user/jwt" \
  -d key="${JWT_ISSUER}" \
  -d secret="${JWT_SECRET}" \
  -d algorithm=HS256 > /dev/null || echo "       (JWT Credential existente)"

# ─── 7. Plugin CORS Global ──────────────────────────
echo ""
echo "[8/8] Habilitando plugin CORS global"
curl -s -X POST "${KONG_ADMIN}/plugins" \
  -d name=cors \
  -d "config.origins=*" \
  -d "config.methods[]=GET" \
  -d "config.methods[]=POST" \
  -d "config.methods[]=PUT" \
  -d "config.methods[]=DELETE" \
  -d "config.methods[]=OPTIONS" \
  -d "config.methods[]=PATCH" \
  -d "config.headers[]=Accept" \
  -d "config.headers[]=Authorization" \
  -d "config.headers[]=Content-Type" \
  -d "config.credentials=false" \
  -d "config.max_age=3600" > /dev/null || \
curl -s -X PATCH "${KONG_ADMIN}/plugins/$(curl -s http://localhost:8001/plugins | grep -oE '"id":"[^"]+"' | head -n 1 | cut -d'"' -f4)" \
  -d "config.origins=*" > /dev/null || echo "       (Plugin CORS atualizado)"

echo ""
echo "================================================="
echo " KONG SETUP — Configuração concluída!"
echo "================================================="


