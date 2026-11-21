#!/bin/bash
set -e

k3d cluster delete iot 2>/dev/null || true
k3d cluster create iot \
  --api-port 6443 \
  --servers 1 \
  --agents 1 \
  -p "8888:8888@loadbalancer" \
  -p "8080:80@loadbalancer" \
  -p "8443:443@loadbalancer"

kubectl wait --for=condition=Ready nodes --all --timeout=120s

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait -n argocd \
  --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  --timeout=300s

kubectl apply -f confs/application.yaml

echo
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
echo
echo "Argo CD UI: в другом терминале запусти и открой https://localhost:8443:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo
echo "Проверка приложения: curl http://localhost:8888 (ожидается {\"status\":\"ok\",\"message\":\"v1\"} после sync)"