terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate SSH key pair for Ansible
resource "tls_private_key" "ansible_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally for reference
resource "local_file" "ansible_private_key" {
  content         = tls_private_key.ansible_ssh_key.private_key_pem
  filename        = "${path.module}/../ansible/ansible_key.pem"
  file_permission = "0600"
}

# Save public key locally for reference
resource "local_file" "ansible_public_key" {
  content         = tls_private_key.ansible_ssh_key.public_key_openssh
  filename        = "${path.module}/../ansible/ansible_key.pub"
  file_permission = "0644"
}

locals {
  ami_id              = var.ubuntu_ami != "" ? var.ubuntu_ami : data.aws_ami.ubuntu.id
  ansible_public_key  = tls_private_key.ansible_ssh_key.public_key_openssh
  ansible_private_key = tls_private_key.ansible_ssh_key.private_key_pem
  
  common_tags = {
    Project     = var.project_name
    Environment = "lab"
    ManagedBy   = "Terraform"
  }
}
