#!/bin/sh
# =============================================================================
# FIAP X — Setup automático dos buckets no MinIO
# =============================================================================
# Credenciais vêm de variáveis de ambiente (definidas no docker-compose)
# =============================================================================

# Configuração do cliente MinIO usando variáveis de ambiente
# MINIO_ROOT_USER e MINIO_ROOT_PASSWORD são injetadas pelo docker-compose
mc alias set myminio http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}

echo "Aguardando MinIO ficar pronto..."
until mc admin info myminio > /dev/null 2>&1; do
  sleep 1
done
echo "MinIO está pronto!"

# Criação dos buckets usando variáveis de ambiente
echo "Criando bucket '${MINIO_BUCKET_RAW}'..."
mc mb myminio/${MINIO_BUCKET_RAW} --ignore-existing

echo "Criando bucket '${MINIO_BUCKET_PROCESSED}'..."
mc mb myminio/${MINIO_BUCKET_PROCESSED} --ignore-existing

echo ""
echo "Buckets criados com sucesso!"
mc ls myminio