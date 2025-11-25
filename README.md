# Fully Automated DevOps Lab on AWS

🚀 **One command to deploy a complete CI/CD environment!**

This project creates a fully automated DevOps infrastructure on AWS with Jenkins, SonarQube, Nexus, and Ansible - all configured via code with zero manual UI configuration.

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/YOUR_USERNAME/devops-lab.git
cd devops-lab

# 2. Configure variables
cat > terraform/terraform.tfvars << EOF
aws_region     = "us-east-1"
key_pair_name  = "your-keypair"
my_ip          = "$(curl -s ifconfig.me)/32"
github_repo    = "https://github.com/YOUR_USERNAME/devops-lab.git"
EOF

# 3. Deploy
cd terraform
terraform init
terraform apply

# 4. Wait 10 minutes, then access Jenkins
# URL from terraform output
# Username: admin
# Password: Admin123!

# 5. Run the pipeline job: java-crud-ci-cd
```

## What You Get

- ✅ **Jenkins** - Fully configured with plugins, credentials, and pipeline job
- ✅ **SonarQube** - Code quality analysis ready to use
- ✅ **Nexus** - Artifact repository with Maven repos
- ✅ **Ansible** - Passwordless SSH to managed nodes
- ✅ **Spring Boot App** - CRUD REST API with tests
- ✅ **Complete Pipeline** - Build → Test → Scan → Deploy → Verify

## Architecture

```
Jenkins (CI/CD) → SonarQube (Quality) → Nexus (Artifacts)
                     ↓
                Ansible Master → App Server (Java App)
```

## Features

- 🎯 **Zero Manual Configuration** - Everything automated via code
- 🔐 **SSH Keys Auto-Generated** - Ansible ready out of the box
- 📦 **Full CI/CD Pipeline** - From code to deployment
- 🧪 **Automated Testing** - Unit tests and smoke tests
- 📊 **Code Quality Gates** - SonarQube integration
- 🚢 **Artifact Management** - Nexus repository
- 🔄 **Infrastructure as Code** - Terraform + Ansible

## Documentation

See [docs/README.md](docs/README.md) for detailed documentation including:
- Prerequisites and setup
- Architecture details
- Customization guide
- Troubleshooting
- API documentation

## Cleanup

```bash
cd terraform
terraform destroy
```

## License

MIT License - see [LICENSE](LICENSE) file

---

**⭐ Star this repo if you find it useful!**
