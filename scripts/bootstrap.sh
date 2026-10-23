#!/usr/bin/env bash
# Primeira execução, do zero: cria o cluster kind, instala o Argo CD e
# aplica a root app (app-of-apps) que sincroniza tudo o mais a partir
# deste repositório.
# Uso: scripts/bootstrap.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Criando cluster kind..."
kind create cluster --config kind/cluster.yaml

echo "==> Instalando Argo CD..."
kubectl apply -k clusters/homelab/bootstrap

echo "==> Aguardando Argo CD ficar pronto..."
kubectl -n argocd wait --for=condition=available --timeout=180s deployment/argocd-server

echo "==> Aplicando a root app (app-of-apps)..."
kubectl apply -f clusters/homelab/root-app.yaml

echo ""
echo "Pronto. Pra ver a UI do Argo CD:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:80"
echo "  usuário: admin"
echo "  senha:   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
