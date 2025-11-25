# Fully Automated DevOps Lab on AWS

A complete, production-ready CI/CD infrastructure that deploys with a single `terraform apply` command. This project demonstrates enterprise DevOps practices with Jenkins, SonarQube, Nexus, and Ansible - all configured automatically via code.

## 🎯 Overview

This project creates a fully automated DevOps environment on AWS that includes:

- **Jenkins** - CI/CD orchestration with Configuration as Code
- **SonarQube** - Code quality and security analysis
- **Nexus Repository** - Artifact management
- **Ansible** - Configuration management and deployment automation
- **Application Server** - Hosts the deployed Spring Boot application

**Everything is configured by code. No manual UI configuration required.**

## 🏗️ Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Jenkins   │────▶│  SonarQube   │     │    Nexus    │
│   (CI/CD)   │     │  (Quality)   │     │ (Artifacts) │
└──────┬──────┘     └──────────────┘     └──────┬──────┘
       │                                          │
       │            ┌──────────────┐             │
       └───────────▶│   Ansible    │◀────────────┘
                    │    Master    │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  App Server  │
                    │  (Java CRUD) │
                    └──────────────┘
```

## 📋 Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** >= 1.0 installed
4. **SSH Key Pair** created in AWS
5. **Git** installed locally

### AWS Permissions Required

Your AWS user/role needs permissions for:
- EC2 (instances, security groups, key pairs)
- VPC (subnets, route tables, internet gateways)
- IAM (if creating roles)

### Local Tools Installation

```bash
# Terraform
# Download from: https://www.terraform.io/downloads

# AWS CLI
# Download from: https://aws.amazon.com/cli/

# Configure AWS credentials
aws configure
```

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/devops-lab.git
cd devops-lab
```

### Step 2: Configure Variables

Create a `terraform.tfvars` file in the `terraform/` directory:

```hcl
# terraform/terraform.tfvars

aws_region     = "us-east-1"
key_pair_name  = "your-aws-keypair-name"
my_ip          = "YOUR.PUBLIC.IP.ADDRESS/32"  # Get from: curl ifconfig.me
github_repo    = "https://github.com/YOUR_USERNAME/devops-lab.git"
project_name   = "devops-lab"
instance_type  = "t3.medium"
```

**Important:** Replace the placeholder values with your actual information.

### Step 3: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted. The deployment takes approximately **10-15 minutes**.

### Step 4: Wait for Services to Initialize

After Terraform completes, wait an additional **5-10 minutes** for all services to:
- Install and configure
- Start up
- Complete their initialization scripts

You can monitor the progress by SSHing into instances:

```bash
# Check Jenkins logs
ssh -i ~/.ssh/your-key.pem ubuntu@<jenkins-ip>
tail -f /var/log/cloud-init-output.log

# Check SonarQube
ssh -i ~/.ssh/your-key.pem ubuntu@<sonar-ip>
tail -f /var/log/cloud-init-output.log
```

### Step 5: Access Jenkins and Run Pipeline

1. **Get the URLs** from Terraform output:
   ```bash
   terraform output
   ```

2. **Open Jenkins** in your browser:
   - URL: `http://<jenkins-ip>:8080`
   - Username: `admin`
   - Password: `Admin123!`

3. **Run the Pipeline**:
   - Click on `java-crud-ci-cd` job
   - Click "Build Now"
   - Watch the pipeline execute all stages

4. **Verify Deployment**:
   - Access the app: `http://<app-server-ip>:8080/health`
   - Should return: `{"status":"UP","application":"Java CRUD App"}`

## 📊 Infrastructure Components

### 1. Jenkins Server
- **Purpose:** CI/CD orchestration
- **Port:** 8080
- **Configured via:** Jenkins Configuration as Code (JCasC)
- **Features:**
  - Pre-configured admin user
  - All plugins installed automatically
  - Credentials configured (SSH, Sonar, Nexus)
  - Pipeline job created automatically

### 2. SonarQube Server
- **Purpose:** Code quality and security analysis
- **Port:** 9000
- **Features:**
  - Admin password set automatically
  - Token generated for Jenkins
  - Ready for immediate use

### 3. Nexus Repository
- **Purpose:** Artifact management
- **Port:** 8081
- **Features:**
  - Admin credentials configured
  - Maven repositories available
  - Integrated with Jenkins pipeline

### 4. Ansible Master
- **Purpose:** Configuration management
- **Features:**
  - SSH keys configured automatically
  - Passwordless access to slave and app server
  - Project repository cloned

### 5. Ansible Slave
- **Purpose:** Managed node (for demonstration)
- **Features:**
  - SSH access configured
  - Ready for Ansible management

### 6. Application Server
- **Purpose:** Hosts the Java CRUD application
- **Port:** 8080
- **Features:**
  - Java 17 pre-installed
  - Systemd service configured
  - Health monitoring enabled

## 🔄 CI/CD Pipeline Flow

The Jenkins pipeline (`java-crud-ci-cd`) automatically executes these stages:

1. **Checkout** - Clone source code from repository
2. **Build** - Compile Java application with Maven
3. **Unit Tests** - Run JUnit tests with coverage
4. **Package** - Create JAR artifact
5. **SonarQube Analysis** - Analyze code quality and security
6. **Publish to Nexus** - Upload artifact to Nexus repository
7. **Deploy with Ansible** - Deploy to application server
8. **Smoke Test** - Verify deployment with health checks

### Pipeline Execution

```bash
# The pipeline runs automatically when you click "Build Now"
# You can also trigger it via:
curl -X POST http://<jenkins-ip>:8080/job/java-crud-ci-cd/build \
  --user admin:Admin123!
```

## 🧪 Testing the Application

### Health Check
```bash
curl http://<app-server-ip>:8080/health
```

Expected response:
```json
{
  "status": "UP",
  "application": "Java CRUD App",
  "version": "1.0.0"
}
```

### CRUD Operations

```bash
# Create an item
curl -X POST http://<app-server-ip>:8080/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"Dell XPS 15","price":1500.00,"quantity":10}'

# Get all items
curl http://<app-server-ip>:8080/api/items

# Get specific item
curl http://<app-server-ip>:8080/api/items/1

# Update item
curl -X PUT http://<app-server-ip>:8080/api/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"Dell XPS 15 Updated","price":1400.00,"quantity":15}'

# Delete item
curl -X DELETE http://<app-server-ip>:8080/api/items/1

# Search by name
curl http://<app-server-ip>:8080/api/items/search?name=Laptop
```

## 🔧 Customization

### Change Application Version

Edit `app/pom.xml`:
```xml
<version>1.0.1</version>
```

Then commit, push, and run the Jenkins pipeline.

### Modify Infrastructure

Edit `terraform/variables.tf` or create/update `terraform.tfvars`:

```hcl
instance_type = "t3.large"  # Use larger instances
aws_region    = "us-west-2"  # Change region
```

Then run:
```bash
terraform apply
```

### Add More Ansible Roles

1. Create a new role in `ansible/roles/`
2. Update `ansible/app_deploy.yml`
3. Commit and push changes
4. Pipeline will use updated playbook

## 📁 Project Structure

```
devops-lab/
├── terraform/
│   ├── main.tf                 # Main Terraform configuration
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── networking.tf           # VPC, subnet, IGW
│   ├── security_groups.tf      # Security group rules
│   └── ec2_instances.tf        # EC2 instance definitions
├── cloud-init/
│   ├── jenkins.sh              # Jenkins setup script
│   ├── sonar.sh                # SonarQube setup script
│   ├── nexus.sh                # Nexus setup script
│   ├── ansible_master.sh       # Ansible master setup
│   ├── ansible_slave.sh        # Ansible slave setup
│   └── app_server.sh           # App server preparation
├── jenkins/
│   ├── jenkins-casc.yaml       # Jenkins Configuration as Code
│   ├── job-dsl.groovy          # Job DSL for pipeline creation
│   └── Jenkinsfile             # Pipeline definition
├── ansible/
│   ├── inventory.ini.tpl       # Inventory template (generated by Terraform)
│   ├── app_deploy.yml          # Main deployment playbook
│   └── roles/
│       └── app_deploy/
│           ├── tasks/main.yml           # Deployment tasks
│           ├── handlers/main.yml        # Service handlers
│           ├── templates/app.service.j2 # Systemd service template
│           └── README.md
├── app/
│   ├── pom.xml                          # Maven configuration
│   └── src/
│       ├── main/java/com/devopslab/crudapp/
│       │   ├── CrudApplication.java            # Spring Boot main class
│       │   ├── model/Item.java                 # Entity model
│       │   ├── repository/ItemRepository.java  # JPA repository
│       │   ├── service/ItemService.java        # Business logic
│       │   └── controller/
│       │       ├── ItemController.java         # REST API
│       │       └── HealthController.java       # Health endpoint
│       ├── resources/application.properties    # App configuration
│       └── test/java/com/devopslab/crudapp/
│           ├── ItemServiceTest.java            # Service tests
│           └── ItemControllerTest.java         # Controller tests
└── docs/
    └── README.md                        # This file
```

## 🔐 Security Considerations

**⚠️ This is a LAB environment. Do NOT use in production without:**

1. **Changing default passwords**
   - Jenkins: `Admin123!`
   - SonarQube: `Admin123!`
   - Nexus: `Admin123!`

2. **Restricting network access**
   - Currently allows access from your IP only for SSH
   - Web interfaces are open to 0.0.0.0/0

3. **Using proper secrets management**
   - Use AWS Secrets Manager or HashiCorp Vault
   - Don't store secrets in plain text

4. **Enabling HTTPS**
   - Add SSL certificates
   - Use AWS ALB with ACM certificates

5. **Implementing proper IAM roles**
   - Use instance profiles
   - Follow principle of least privilege

## 🐛 Troubleshooting

### Issue: Jenkins doesn't start

**Solution:**
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<jenkins-ip>
sudo systemctl status jenkins
sudo journalctl -u jenkins -f
```

### Issue: SonarQube takes too long to start

**Solution:** SonarQube needs 2-3 minutes and requires adequate memory. Ensure you're using at least t3.medium instances.

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<sonar-ip>
sudo systemctl status sonarqube
tail -f /opt/sonarqube/sonarqube/logs/sonar.log
```

### Issue: Ansible can't connect to app server

**Solution:**
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<ansible-master-ip>
cd /opt/devops-lab
ansible all -m ping
```

If failing, check:
- SSH keys are properly configured
- Security groups allow traffic
- `/home/ubuntu/.ssh/config` has `StrictHostKeyChecking no`

### Issue: Pipeline fails at SonarQube stage

**Solution:** 
- Ensure SonarQube is fully started (check port 9000)
- Verify token in Jenkins credentials
- Check SonarQube logs

### Issue: Nexus admin password not working

**Solution:**
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<nexus-ip>
cat /opt/nexus/sonatype-work/nexus3/admin.password
```

Use this password to login, then check if the script completed password change.

## 🧹 Cleanup

To destroy all resources and avoid AWS charges:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This will:
- Terminate all EC2 instances
- Delete security groups
- Remove VPC and networking components
- Clean up local generated files

## 📚 Additional Resources

- [Jenkins Configuration as Code](https://github.com/jenkinsci/configuration-as-code-plugin)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [SonarQube Documentation](https://docs.sonarqube.org/latest/)
- [Nexus Repository Manager](https://help.sonatype.com/repomanager3)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

Created as a demonstration of enterprise DevOps practices and Infrastructure as Code.

## 🎓 Learning Outcomes

By working with this project, you'll learn:

- ✅ Infrastructure as Code with Terraform
- ✅ Configuration Management with Ansible
- ✅ CI/CD pipeline design with Jenkins
- ✅ Code quality analysis with SonarQube
- ✅ Artifact management with Nexus
- ✅ Spring Boot application development
- ✅ Automated testing and deployment
- ✅ Cloud-init and user-data scripts
- ✅ AWS networking and security groups
- ✅ Systemd service management

## 📞 Support

If you encounter issues:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review the logs on each server
3. Verify your `terraform.tfvars` configuration
4. Ensure your AWS credentials are correct
5. Open an issue on GitHub with:
   - Error message
   - Terraform output
   - Relevant logs

---

**Happy DevOps Learning! 🚀**
