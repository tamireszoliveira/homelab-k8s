# Usa a VPC/subnet default da conta: é uma caixa pessoal de homelab, não
# vale a pena desenhar rede própria (VPC/IGW/route tables) para isso.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_key_pair" "rancher" {
  key_name   = "${var.key_name_prefix}-${random_id.suffix.hex}"
  public_key = tls_private_key.ssh.public_key_openssh
}

# Chave privada só existe no state do Terraform e neste arquivo local —
# não versionar infra-aws/rancher_ssh_key.pem (ver .gitignore).
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/rancher_ssh_key.pem"
  file_permission = "0600"
}

resource "random_password" "bootstrap" {
  length  = 24
  special = false # evita problemas de escaping na env var do container
}

resource "aws_security_group" "rancher" {
  name        = "homelab-rancher"
  description = "SSH e UI do Rancher, restrito ao IP de origem configurado"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Rancher UI (HTTPS)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "homelab-rancher"
  }
}

resource "aws_instance" "rancher" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.rancher.id]
  key_name               = aws_key_pair.rancher.key_name

  # Sem Elastic IP de propósito: um IP reservado cobra 24/7 mesmo parado,
  # o que anularia a economia de ligar só quando for usar (ver scripts/).
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    rancher_version    = "v2.15.2"
    bootstrap_password = random_password.bootstrap.result
  })

  tags = {
    Name = "homelab-rancher"
  }
}

output "instance_id" {
  value = aws_instance.rancher.id
}

output "aws_region" {
  value = var.aws_region
}

output "ssh_private_key_path" {
  value = local_sensitive_file.private_key.filename
}

output "bootstrap_password" {
  value     = random_password.bootstrap.result
  sensitive = true
}

output "public_ip_at_apply_time" {
  description = "Só vale no momento do apply. Depois de start/stop, use scripts/cluster-up.sh para descobrir o IP atual."
  value       = aws_instance.rancher.public_ip
}
