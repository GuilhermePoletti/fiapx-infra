#!/bin/bash
# =============================================================================
# FIAP X - MICROSERVICES DEPLOYMENT SCRIPT (E2E TEST)
# =============================================================================
# Ele destroi execuções anteriores no namespace 'fiapx' e recria a 
# arquitetura inteira, incluindo Secrets, Bancos de Dados e Deployments.
# =============================================================================

echo "[1/7] Limpando ambiente Kubernetes anterior no namespace 'fiapx'..."
kubectl delete all --all -n fiapx
kubectl delete configmap --all -n fiapx
kubectl delete secret --all -n fiapx
kubectl delete pvc --all -n fiapx

echo "[2/7] Aplicando Namespace, Secrets e ConfigMaps fixos..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/postgres-init-configmap.yaml

echo "[3/7] Injetando Scripts utilitários como ConfigMaps dinâmicos..."
kubectl create configmap swagger-config --from-file=infra/swagger/swagger-config.json -n fiapx
kubectl create configmap infra-scripts --from-file=infra/kong/setup-kong.sh --from-file=infra/minio/setup-buckets.sh -n fiapx

echo "[4/7] Subindo Infraestrutura Base (Bancos, Storages e Mensageria)..."
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/rabbitmq-deployment.yaml
kubectl apply -f k8s/minio-deployment.yaml
kubectl apply -f k8s/redis-deployment.yaml
kubectl apply -f k8s/kong-deployment.yaml
kubectl apply -f k8s/mailhog-deployment.yaml

echo "      [Wait] Aguardando 15 segundos para os Bancos iniciarem os containers..."
sleep 15

echo "[5/7] Executando Job do Kong Migrations (Bootstrap banco de rotas)..."
kubectl apply -f k8s/kong-migrations-job.yaml

echo "[6/7] Subindo os Microsserviços da Aplicação FIAPX..."
kubectl apply -f k8s/auth-deployment.yaml
kubectl apply -f k8s/manager-deployment.yaml
kubectl apply -f k8s/worker-deployment.yaml
kubectl apply -f k8s/notifier-deployment.yaml
kubectl apply -f k8s/swagger-deployment.yaml

echo "      [Wait] Aguardando 30 segundos para o warmup dos containers Node.js..."
sleep 30

echo "[7/7] Executando Jobs Autônomos de Configuração Final (Rotas e Buckets)..."
kubectl apply -f k8s/minio-setup-job.yaml
kubectl apply -f k8s/kong-setup-job.yaml

echo "====================================================================="
echo " DEPLOY CONCLUÍDO!                                                  "
echo "====================================================================="
echo ""
echo " Acompanhe o status dos pods: kubectl get pods -n fiapx"
echo ""
echo " Para acessar os serviços no Windows, abra 3 terminais e rode:"
echo ""
echo "   Terminal 1 (Swagger):  kubectl port-forward svc/swagger-ui -n fiapx 30085:8080"
echo "   Terminal 2 (API Kong): kubectl port-forward svc/kong -n fiapx 30080:8000"
echo "   Terminal 3 (Mailhog):  kubectl port-forward svc/mailhog -n fiapx 30082:8025"
echo ""
echo " Links de Acesso:"
echo "   Swagger UI:  http://localhost:30085"
echo "   Mailhog:     http://localhost:30082"
echo "====================================================================="
