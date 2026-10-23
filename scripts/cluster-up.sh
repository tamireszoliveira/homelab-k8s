#!/usr/bin/env bash
# Liga a instância do Rancher e imprime a URL de acesso.
# Uso: scripts/cluster-up.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../infra-aws"

INSTANCE_ID=$(terraform output -raw instance_id)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' --output text --region "$REGION")

if [[ "$STATE" == "stopped" ]]; then
  echo "Ligando $INSTANCE_ID..."
  aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null
fi

echo "Aguardando status 'running'..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region "$REGION")

echo "Aguardando SSH responder..."
for _ in $(seq 1 30); do
  if nc -z -w2 "$PUBLIC_IP" 22 2>/dev/null; then
    break
  fi
  sleep 5
done

HOSTNAME="${PUBLIC_IP}.sslip.io"
echo ""
echo "IP público atual: $PUBLIC_IP"
echo "Rancher (pode levar 1-2 min pra responder no primeiro acesso após boot):"
echo "  https://${HOSTNAME}"
echo ""
echo "SSH:"
echo "  ssh -i infra-aws/rancher_ssh_key.pem ubuntu@${PUBLIC_IP}"
