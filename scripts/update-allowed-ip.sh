#!/usr/bin/env bash
# Seu IP de casa mudou e SSH/UI do Rancher pararam de responder? Rode este
# script: ele detecta seu IP público atual e reaplica o Terraform só com
# essa variável, sem precisar editar nada à mão.
# Uso: scripts/update-allowed-ip.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../infra-aws"

MY_IP=$(curl -fsSL -4 https://checkip.amazonaws.com)
MY_IP="${MY_IP//[[:space:]]/}"

echo "IP público detectado: ${MY_IP}/32"
terraform apply -var="allowed_cidr=${MY_IP}/32" "$@"
