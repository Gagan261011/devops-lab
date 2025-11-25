#!/bin/bash

# Quick setup script for DevOps Lab
# This script helps you get started quickly

set -e

echo "=================================="
echo "DevOps Lab Quick Setup"
echo "=================================="
echo ""

# Check for required tools
echo "Checking prerequisites..."

command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is not installed. Install from: https://www.terraform.io/downloads"; exit 1; }
echo "✅ Terraform found: $(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)"

command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI is not installed. Install from: https://aws.amazon.com/cli/"; exit 1; }
echo "✅ AWS CLI found: $(aws --version | cut -d' ' -f1)"

command -v git >/dev/null 2>&1 || { echo "❌ Git is not installed."; exit 1; }
echo "✅ Git found: $(git --version | cut -d' ' -f3)"

echo ""
echo "Checking AWS credentials..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "✅ AWS credentials configured (Account: $ACCOUNT_ID)"
else
    echo "❌ AWS credentials not configured. Run: aws configure"
    exit 1
fi

echo ""
echo "Getting your public IP..."
MY_IP=$(curl -s ifconfig.me)
echo "✅ Your IP: $MY_IP"

echo ""
echo "=================================="
echo "Configuration"
echo "=================================="

# Get user inputs
read -p "Enter your AWS key pair name: " KEY_PAIR_NAME
read -p "Enter your GitHub repo URL [https://github.com/YOUR_USERNAME/devops-lab.git]: " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-"https://github.com/YOUR_USERNAME/devops-lab.git"}

read -p "Enter AWS region [us-east-1]: " AWS_REGION
AWS_REGION=${AWS_REGION:-"us-east-1"}

read -p "Enter instance type [t3.medium]: " INSTANCE_TYPE
INSTANCE_TYPE=${INSTANCE_TYPE:-"t3.medium"}

# Create terraform.tfvars
echo ""
echo "Creating terraform.tfvars..."
cat > terraform/terraform.tfvars << EOF
aws_region     = "$AWS_REGION"
key_pair_name  = "$KEY_PAIR_NAME"
my_ip          = "$MY_IP/32"
github_repo    = "$GITHUB_REPO"
project_name   = "devops-lab"
instance_type  = "$INSTANCE_TYPE"
ubuntu_ami     = ""
EOF

echo "✅ terraform.tfvars created"

echo ""
echo "=================================="
echo "Ready to Deploy!"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. cd terraform"
echo "2. terraform init"
echo "3. terraform plan"
echo "4. terraform apply"
echo ""
echo "After deployment:"
echo "- Wait 10 minutes for services to initialize"
echo "- Access Jenkins at the URL shown in terraform output"
echo "- Login with admin / Admin123!"
echo "- Run the pipeline job: java-crud-ci-cd"
echo ""
echo "To destroy everything later: terraform destroy"
echo ""
echo "=================================="

read -p "Do you want to proceed with terraform init? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd terraform
    terraform init
    echo ""
    echo "✅ Terraform initialized!"
    echo ""
    echo "Run 'terraform apply' to deploy the infrastructure."
fi
