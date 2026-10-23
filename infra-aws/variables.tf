variable "aws_region" {
  description = "Região AWS onde a instância do Rancher roda."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "t3a.medium: 2 vCPU / 4GB, atende o mínimo oficial do Rancher (Docker single-node)."
  type        = string
  default     = "t3a.medium"
}

variable "root_volume_size_gb" {
  description = "Disco raiz em GB. Cobrado 24/7 (gp3, ~$0.08/GB-mês) independente da instância estar ligada ou parada — é o único custo fixo deste setup."
  type        = number
  default     = 40
}

variable "allowed_cidr" {
  description = <<-EOT
    CIDR (seu-ip/32) autorizado a acessar SSH (22) e a UI do Rancher (443).
    Sem default de propósito — este repositório é público, e um IP doméstico
    fixo no código ficaria exposto pra sempre no histórico do git. Informe
    na primeira vez com scripts/update-allowed-ip.sh (detecta seu IP atual
    e aplica), ou manualmente com -var="allowed_cidr=SEU.IP.AQUI/32".
  EOT
  type        = string
}

variable "key_name_prefix" {
  description = "Prefixo do nome do key pair criado na AWS."
  type        = string
  default     = "homelab-rancher"
}
