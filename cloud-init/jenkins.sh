#!/bin/bash
set -e

# Jenkins Installation and Configuration Script
# This script installs Jenkins and configures it using Configuration as Code (JCasC)

echo "=== Starting Jenkins Installation ==="

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install Java 17
apt-get install -y openjdk-17-jdk

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update
apt-get install -y jenkins

# Install Git and other dependencies
apt-get install -y git maven curl

# Create directory for the project
mkdir -p /opt/devops-lab
chown jenkins:jenkins /opt/devops-lab

# Wait for Jenkins to start initially
systemctl start jenkins
sleep 30

# Disable setup wizard
mkdir -p /var/lib/jenkins/init.groovy.d
cat > /var/lib/jenkins/init.groovy.d/basic-security.groovy << 'EOF'
#!groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
println "--> Disabling setup wizard"
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
instance.save()
EOF

# Configure Jenkins home
export JENKINS_HOME=/var/lib/jenkins

# Create plugins.txt for plugin installation
cat > /tmp/plugins.txt << 'EOF'
configuration-as-code:latest
job-dsl:latest
git:latest
workflow-aggregator:latest
credentials:latest
credentials-binding:latest
ssh-credentials:latest
ssh-agent:latest
sonar:latest
nexus-artifact-uploader:latest
ansible:latest
ansicolor:latest
pipeline-stage-view:latest
maven-plugin:latest
EOF

# Download Jenkins CLI
sleep 10
wget http://localhost:8080/jnlpJars/jenkins-cli.jar -O /tmp/jenkins-cli.jar

# Install plugins
echo "=== Installing Jenkins Plugins ==="
while IFS= read -r plugin; do
  plugin_name=$(echo "$plugin" | cut -d: -f1)
  echo "Installing $plugin_name..."
  java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ install-plugin "$plugin_name" -restart || true
done < /tmp/plugins.txt

# Wait for Jenkins to restart
sleep 60

# Create JCasC directory
mkdir -p /var/lib/jenkins/casc_configs
chown jenkins:jenkins /var/lib/jenkins/casc_configs

# Store Ansible private key for Jenkins
cat > /var/lib/jenkins/ansible_key.pem << 'ANSIBLEKEY'
${ansible_private_key}
ANSIBLEKEY
chown jenkins:jenkins /var/lib/jenkins/ansible_key.pem
chmod 600 /var/lib/jenkins/ansible_key.pem

# Create environment file with configuration
cat > /etc/default/jenkins_env << 'EOF'
SONAR_URL=${sonar_url}
NEXUS_URL=${nexus_url}
ANSIBLE_MASTER_IP=${ansible_master_ip}
GITHUB_REPO=${github_repo}
EOF

# Configure Jenkins to use JCasC
cat > /etc/default/jenkins << 'JENKINSCONFIG'
JENKINS_ARGS="--webroot=/var/cache/$NAME/war --httpPort=$HTTP_PORT"
JAVA_ARGS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -Dcasc.jenkins.config=/var/lib/jenkins/casc_configs/jenkins-casc.yaml"
JENKINSCONFIG

# Clone the project repository (retry logic)
echo "=== Cloning project repository ==="
for i in {1..5}; do
  if su - jenkins -c "cd /opt/devops-lab && git clone ${github_repo} . 2>/dev/null || git pull 2>/dev/null"; then
    echo "Repository cloned/updated successfully"
    break
  else
    echo "Attempt $i failed, waiting 30 seconds..."
    sleep 30
  fi
done

# Copy JCasC configuration
if [ -f "/opt/devops-lab/jenkins/jenkins-casc.yaml" ]; then
  cp /opt/devops-lab/jenkins/jenkins-casc.yaml /var/lib/jenkins/casc_configs/
  chown jenkins:jenkins /var/lib/jenkins/casc_configs/jenkins-casc.yaml
  
  # Replace placeholders in JCasC
  sed -i "s|SONAR_URL_PLACEHOLDER|${sonar_url}|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
  sed -i "s|NEXUS_URL_PLACEHOLDER|${nexus_url}|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
  sed -i "s|ANSIBLE_MASTER_IP_PLACEHOLDER|${ansible_master_ip}|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
  sed -i "s|GITHUB_REPO_PLACEHOLDER|${github_repo}|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
fi

# Restart Jenkins to apply JCasC
systemctl restart jenkins

echo "=== Jenkins Installation Complete ==="
echo "Jenkins will be available at http://<server-ip>:8080"
echo "Default credentials: admin / Admin123!"
