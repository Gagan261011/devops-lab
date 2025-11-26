#!/bin/bash
set -e

# Jenkins Installation and Configuration Script
# This script installs Jenkins and configures it using Configuration as Code (JCasC)

echo "=== Starting Jenkins Installation ==="
exec > >(tee -a /var/log/jenkins-install.log)
exec 2>&1

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
apt-get install -y git maven curl unzip

# Create directory for the project
mkdir -p /opt/devops-lab
chown jenkins:jenkins /opt/devops-lab

# Configure Jenkins to skip setup wizard from the start
mkdir -p /var/lib/jenkins
echo "2.0" > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion
echo "2.0" > /var/lib/jenkins/jenkins.install.UpgradeWizard.state
chown -R jenkins:jenkins /var/lib/jenkins

# Configure JAVA_OPTS before starting Jenkins
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
EOF

systemctl daemon-reload

# Start Jenkins
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to be ready
echo "Waiting for Jenkins to start..."
for i in {1..60}; do
  if curl -s http://localhost:8080/api/json > /dev/null 2>&1; then
    echo "Jenkins is up!"
    break
  fi
  echo "Waiting... attempt $i/60"
  sleep 5
done

# Install Jenkins plugins using plugin installation manager
echo "=== Installing Jenkins Plugins ==="
PLUGIN_CLI_URL="https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.12.13/jenkins-plugin-manager-2.12.13.jar"
wget -q "$PLUGIN_CLI_URL" -O /tmp/jenkins-plugin-manager.jar

# List of plugins
PLUGINS="configuration-as-code:latest git:latest workflow-aggregator:latest credentials:latest credentials-binding:latest ssh-credentials:latest ssh-agent:latest sonar:latest ansible:latest ansicolor:latest pipeline-stage-view:latest maven-plugin:latest"

# Install plugins
java -jar /tmp/jenkins-plugin-manager.jar \
  --war /usr/share/java/jenkins.war \
  --plugin-download-directory /var/lib/jenkins/plugins \
  --plugins $PLUGINS || echo "Plugin installation had some warnings, continuing..."

chown -R jenkins:jenkins /var/lib/jenkins/plugins

# Restart Jenkins to load plugins
systemctl restart jenkins

# Wait for Jenkins to restart
echo "Waiting for Jenkins to restart..."
sleep 30
for i in {1..60}; do
  if curl -s http://localhost:8080/api/json > /dev/null 2>&1; then
    echo "Jenkins restarted successfully!"
    break
  fi
  sleep 5
done

# Store Ansible private key for Jenkins
mkdir -p /var/lib/jenkins/.ssh
cat > /var/lib/jenkins/.ssh/ansible_key.pem << 'ANSIBLEKEY'
${ansible_private_key}
ANSIBLEKEY
chown -R jenkins:jenkins /var/lib/jenkins/.ssh
chmod 700 /var/lib/jenkins/.ssh
chmod 600 /var/lib/jenkins/.ssh/ansible_key.pem

# Clone the project repository (retry logic)
echo "=== Cloning project repository ==="
for i in {1..10}; do
  if su - jenkins -c "cd /opt/devops-lab && git clone ${github_repo} . 2>/dev/null || (git fetch && git reset --hard origin/main) 2>/dev/null"; then
    echo "Repository cloned/updated successfully"
    break
  else
    echo "Attempt $i failed, waiting 20 seconds..."
    sleep 20
  fi
done

# Configure Jenkins with credentials, tools, and job using Groovy
echo "=== Configuring Jenkins via Groovy Script ==="
cat > /var/lib/jenkins/init.groovy.d/setup-jenkins.groovy << 'GROOVYSCRIPT'
#!groovy
import jenkins.model.*
import hudson.security.*
import hudson.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*
import hudson.plugins.sonar.*
import hudson.plugins.sonar.model.TriggersConfig
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.GitSCM
import hudson.plugins.git.BranchSpec

def instance = Jenkins.getInstance()

println "=== Starting Jenkins Configuration ==="

// 1. Create admin user and security
try {
    def hudsonRealm = new HudsonPrivateSecurityRealm(false)
    hudsonRealm.createAccount("admin", "Admin123!")
    instance.setSecurityRealm(hudsonRealm)
    
    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)
    instance.setAuthorizationStrategy(strategy)
    
    println "✓ Admin user created"
} catch (Exception e) {
    println "Admin user already exists"
}

// 2. Set global environment variables
def globalNodeProperties = instance.getGlobalNodeProperties()
def envVarsNodePropertyList = globalNodeProperties.getAll(hudson.slaves.EnvironmentVariablesNodeProperty.class)

def envVars = null
if (envVarsNodePropertyList == null || envVarsNodePropertyList.size() == 0) {
  def newEnvVarsNodeProperty = new hudson.slaves.EnvironmentVariablesNodeProperty()
  globalNodeProperties.add(newEnvVarsNodeProperty)
  envVars = newEnvVarsNodeProperty.getEnvVars()
} else {
  envVars = envVarsNodePropertyList.get(0).getEnvVars()
}

envVars.put("NEXUS_URL", "NEXUS_IP_PLACEHOLDER:8081")
envVars.put("SONAR_HOST_URL", "http://SONAR_IP_PLACEHOLDER:9000")
println "✓ Environment variables set"

// 3. Configure Credentials
def domain = Domain.global()
def store = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

// SSH key for Ansible
if (new File('/var/lib/jenkins/.ssh/ansible_key.pem').exists()) {
    try {
        def sshKey = new BasicSSHUserPrivateKey(
            CredentialsScope.GLOBAL,
            "ansible-ssh-key",
            "ubuntu",
            new BasicSSHUserPrivateKey.FileOnMasterPrivateKeySource('/var/lib/jenkins/.ssh/ansible_key.pem'),
            "",
            "SSH key for Ansible deployments"
        )
        store.addCredentials(domain, sshKey)
        println "✓ Ansible SSH key added"
    } catch (Exception e) {
        println "Ansible SSH key already exists"
    }
}

// SonarQube token (placeholder, will be updated later)
try {
    def sonarToken = new StringCredentialsImpl(
        CredentialsScope.GLOBAL,
        "sonar-token",
        "SonarQube authentication token",
        Secret.fromString("squ_placeholder_will_be_updated")
    )
    store.addCredentials(domain, sonarToken)
    println "✓ SonarQube token placeholder added"
} catch (Exception e) {
    println "SonarQube token already exists"
}

// Nexus credentials
try {
    def nexusCreds = new UsernamePasswordCredentialsImpl(
        CredentialsScope.GLOBAL,
        "nexus-credentials",
        "Nexus Repository credentials",
        "admin",
        "Admin123!"
    )
    store.addCredentials(domain, nexusCreds)
    println "✓ Nexus credentials added"
} catch (Exception e) {
    println "Nexus credentials already exist"
}

// 4. Configure SonarQube server
try {
    def sonarDesc = instance.getDescriptor("hudson.plugins.sonar.SonarGlobalConfiguration")
    def sonarInst = new SonarInstallation(
        "SonarQube",
        "http://SONAR_IP_PLACEHOLDER:9000",
        "sonar-token",
        "",
        "",
        "",
        "",
        "",
        new TriggersConfig()
    )
    sonarDesc.setInstallations(sonarInst)
    sonarDesc.save()
    println "✓ SonarQube server configured"
} catch (Exception e) {
    println "SonarQube configuration: " + e.getMessage()
}

// 5. Configure Maven
try {
    def mavenDesc = instance.getDescriptor("hudson.tasks.Maven")
    def mavenInstaller = new hudson.tasks.Maven.MavenInstaller("3.9.5")
    def mavenInstallation = new hudson.tasks.Maven.MavenInstallation(
        "Maven-3.9",
        "",
        [new hudson.tools.InstallSourceProperty([mavenInstaller])]
    )
    mavenDesc.setInstallations(mavenInstallation)
    mavenDesc.save()
    println "✓ Maven configured"
} catch (Exception e) {
    println "Maven configuration: " + e.getMessage()
}

// 6. Configure JDK
try {
    def jdkDesc = instance.getDescriptor("hudson.model.JDK")
    def jdk = new hudson.model.JDK("JDK-17", "/usr/lib/jvm/java-17-openjdk-amd64")
    jdkDesc.setInstallations(jdk)
    jdkDesc.save()
    println "✓ JDK configured"
} catch (Exception e) {
    println "JDK configuration: " + e.getMessage()
}

// 7. Create Pipeline Job
try {
    def jobName = "java-crud-ci-cd"
    def job = instance.getItem(jobName)
    
    if (job == null) {
        job = instance.createProject(WorkflowJob.class, jobName)
        
        def scm = new GitSCM("GITHUB_REPO_PLACEHOLDER")
        scm.branches = [new BranchSpec("*/main")]
        
        def definition = new CpsScmFlowDefinition(scm, "jenkins/Jenkinsfile")
        definition.setLightweight(false)
        
        job.setDefinition(definition)
        job.setDescription("Full CI/CD pipeline for Java CRUD application")
        job.save()
        
        println "✓ Pipeline job 'java-crud-ci-cd' created"
    } else {
        println "Pipeline job already exists"
    }
} catch (Exception e) {
    println "Job creation error: " + e.getMessage()
}

instance.save()
println "=== Jenkins Configuration Complete ==="
GROOVYSCRIPT

# Replace placeholders in the Groovy script
SONAR_IP=$(echo "${sonar_url}" | grep -oP '\d+\.\d+\.\d+\.\d+')
NEXUS_IP=$(echo "${nexus_url}" | grep -oP '\d+\.\d+\.\d+\.\d+')

sed -i "s|NEXUS_IP_PLACEHOLDER|$NEXUS_IP|g" /var/lib/jenkins/init.groovy.d/setup-jenkins.groovy
sed -i "s|SONAR_IP_PLACEHOLDER|$SONAR_IP|g" /var/lib/jenkins/init.groovy.d/setup-jenkins.groovy
sed -i "s|GITHUB_REPO_PLACEHOLDER|${github_repo}|g" /var/lib/jenkins/init.groovy.d/setup-jenkins.groovy

chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/setup-jenkins.groovy

# Restart Jenkins to execute init scripts
echo "Restarting Jenkins to apply configuration..."
systemctl restart jenkins

# Wait for final startup
echo "Waiting for Jenkins to complete configuration..."
sleep 45
for i in {1..60}; do
  if curl -s http://localhost:8080/api/json > /dev/null 2>&1; then
    echo "Jenkins is ready!"
    break
  fi
  sleep 5
done

# Run post-configuration to update SonarQube token
sleep 10
echo "=== Running post-configuration ==="

# Wait for SonarQube and update token
(
  sleep 120  # Wait 2 minutes for SonarQube to be ready
  
  # Try to get SonarQube token
  for i in {1..20}; do
    SONAR_TOKEN=$(curl -s -u admin:Admin123! -X POST "http://$SONAR_IP:9000/api/user_tokens/generate?name=jenkins-token" 2>/dev/null | grep -oP '"token":"\K[^"]+')
    
    if [ -n "$SONAR_TOKEN" ]; then
      echo "Got SonarQube token, updating Jenkins..."
      
      # Update credential via Groovy
      cat > /tmp/update-sonar-token.groovy << UPDATETOKEN
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import jenkins.model.Jenkins

def instance = Jenkins.getInstance()
def domain = Domain.global()
def store = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

def sonarToken = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "sonar-token",
    "SonarQube authentication token",
    Secret.fromString("$SONAR_TOKEN")
)

def existing = store.getCredentials(domain).find { it.id == "sonar-token" }
if (existing) {
    store.updateCredentials(domain, existing, sonarToken)
    println "SonarQube token updated"
}
UPDATETOKEN
      
      curl -s -u admin:Admin123! --data-urlencode "script@/tmp/update-sonar-token.groovy" http://localhost:8080/scriptText
      echo "✓ SonarQube token updated in Jenkins"
      break
    fi
    
    echo "Waiting for SonarQube... attempt $i/20"
    sleep 15
  done
) &

echo "=== Jenkins Installation Complete ==="
echo "Jenkins URL: http://<server-ip>:8080"
echo "Username: admin"
echo "Password: Admin123!"
echo "Job: java-crud-ci-cd"
