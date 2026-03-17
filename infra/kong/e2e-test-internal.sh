#!/bin/sh
set -e

KONG_URL="http://kong:8000"
CPF="12345678901"
PASSWORD="Password123"

echo "[1/5] Registrando Usuário..."
REG_DATA="{\"cpf\":\"$CPF\",\"password\":\"$PASSWORD\",\"name\":\"E2E Test User\",\"email\":\"e2e@test.com\"}"
REG_RES=$(curl -s -X POST "${KONG_URL}/auth/register" -H "Content-Type: application/json" -d "$REG_DATA")
echo "      Resposta: $REG_RES"

echo "[2/5] Realizando Login..."
LOGIN_DATA="{\"cpf\":\"$CPF\",\"password\":\"$PASSWORD\"}"
LOGIN_RES=$(curl -s -X POST "${KONG_URL}/auth/login" -H "Content-Type: application/json" -d "$LOGIN_DATA")
JWT=$(echo $LOGIN_RES | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4)

if [ -z "$JWT" ]; then
    echo "      ERRO: Não foi possível obter o JWT"
    exit 1
fi
echo "      Sucesso! Token obtido."

echo "[3/5] Fazendo Upload de vídeo..."
# Criar um arquivo dummy de vídeo
echo "dummy video" > test.mp4
UPLOAD_RES=$(curl -s -X POST "${KONG_URL}/videos" \
    -H "Authorization: Bearer $JWT" \
    -F "file=@test.mp4;type=video/mp4")
VIDEO_ID=$(echo $UPLOAD_RES | grep -oE '"id":"[^"]+"' | head -n 1 | cut -d'"' -f4)

if [ -z "$VIDEO_ID" ]; then
    echo "      ERRO no Upload: $UPLOAD_RES"
    exit 1
fi
echo "      Sucesso! Vídeo ID: $VIDEO_ID"

echo "[4/5] Aguardando processamento (Polling)..."
STATUS="RECEBIDO"
ATTEMPTS=0
while [ "$STATUS" != "CONCLUIDO" ] && [ $ATTEMPTS -lt 20 ]; do
    sleep 5
    CHECK_RES=$(curl -s -G "${KONG_URL}/videos/$VIDEO_ID" -H "Authorization: Bearer $JWT")
    STATUS=$(echo $CHECK_RES | grep -oE '"status":"[^"]+"' | cut -d'"' -f4)
    echo "      Tentativa $ATTEMPTS: Status = $STATUS"
    if [ "$STATUS" = "ERRO" ]; then
        echo "      ERRO no processamento: $CHECK_RES"
        exit 1
    fi
    ATTEMPTS=$((ATTEMPTS+1))
done

if [ "$STATUS" = "CONCLUIDO" ]; then
    echo "[5/5] Testando link de Download..."
    DW_RES=$(curl -s -G "${KONG_URL}/videos/$VIDEO_ID/download" -H "Authorization: Bearer $JWT")
    DW_URL=$(echo $DW_RES | grep -oE '"downloadUrl":"[^"]+"' | cut -d'"' -f4)
    if [ -n "$DW_URL" ]; then
        echo "      Sucesso! URL de download obtida: ${DW_URL:0:50}..."
        echo "================================================="
        echo " E2E TEST PASSED SUCCESSFULLY!"
        echo "================================================="
    else
        echo "      ERRO ao obter URL de download: $DW_RES"
        exit 1
    fi
else
    echo "      ERRO: Tempo esgotado aguardando processamento"
    exit 1
fi
