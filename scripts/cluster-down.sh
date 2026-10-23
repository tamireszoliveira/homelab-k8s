#!/usr/bin/env bash
# Para a instância do Rancher. Dados em /var/lib/rancher persistem no disco
# (continua sendo cobrado só o EBS, ~R$16/mês fixos — ver infra-aws/variables.tf).
# Uso: scripts/cluster-down.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../infra-aws"

INSTANCE_ID=$(terraform output -raw instance_id)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

echo "Parando $INSTANCE_ID..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "Parada. Só o disco (EBS) continua sendo cobrado enquanto ela existir."
