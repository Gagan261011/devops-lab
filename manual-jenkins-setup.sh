#!/bin/bash

# Manual setup for Jenkins - creates admin user, credentials, tools, and job

echo "=== Setting up Jenkins manually ===" 

# Get IPs
SONAR_IP="$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)/vpc-ipv4-cidr-blocks | cut -d'.' -f1-3).0/24"
NEXUS_IP="$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)/vpc-ipv4-cidr-blocks | cut -d'.' -f1-3).0/24"

# Get from terraform output
SONAR_IP="3.93.220.226"  
NEXUS_IP="54.89.104.105"

# Create Groovy script
mkdir -p /tmp
cat > /tmp/setup-all.groovy << 'GROOVYEOF'
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

println "Starting complete Jenkins setup..."

// 1. Create admin user
try {
    def hudsonRealm = new HudsonPrivateSecurityRealm(false)
    hudsonRealm.createAccount("admin", "Admin123!")
    instance.setSecurityRealm(hudsonRealm)
    
    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)
    instance.setAuthorizationStrategy(strategy)
    
    println "✓ Admin user created"
} catch (Exception e) {
    println "Admin already exists: " + e.getMessage()
}

// 2. Set environment variables
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

// 3. Setup credentials
def domain = Domain.global()
def store = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

// SSH key
if (new File('/var/lib/jenkins/.ssh/ansible_key.pem').exists()) {
    try {
        def sshKey = new BasicSSHUserPrivateKey(
            CredentialsScope.GLOBAL,
            "ansible-ssh-key",
            "ubuntu",
            new BasicSSHUserPrivateKey.FileOnMasterPrivateKeySource('/var/lib/jenkins/.ssh/ansible_key.pem'),
            "",
            "SSH key for Ansible"
        )
        store.addCredentials(domain, sshKey)
        println "✓ Ansible SSH key added"
    } catch (Exception e) {
        println "SSH key exists"
    }
}

// SonarQube token
try {
    def sonarToken = new StringCredentialsImpl(
        CredentialsScope.GLOBAL,
        "sonar-token",
        "SonarQube token",
        Secret.fromString("squ_placeholder")
    )
    store.addCredentials(domain, sonarToken)
    println "✓ SonarQube token added"
} catch (Exception e) {
    println "SonarQube token exists"
}

// Nexus
try {
    def nexusCreds = new UsernamePasswordCredentialsImpl(
        CredentialsScope.GLOBAL,
        "nexus-credentials",
        "Nexus credentials",
        "admin",
        "Admin123!"
    )
    store.addCredentials(domain, nexusCreds)
    println "✓ Nexus credentials added"
} catch (Exception e) {
    println "Nexus credentials exist"
}

// 4. Configure tools
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
    println "Maven: " + e.getMessage()
}

try {
    def jdkDesc = instance.getDescriptor("hudson.model.JDK")
    def jdk = new hudson.model.JDK("JDK-17", "/usr/lib/jvm/java-17-openjdk-amd64")
    jdkDesc.setInstallations(jdk)
    jdkDesc.save()
    println "✓ JDK configured"
} catch (Exception e) {
    println "JDK: " + e.getMessage()
}

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
    println "SonarQube: " + e.getMessage()
}

// 5. Create job
try {
    def jobName = "java-crud-ci-cd"
    def job = instance.getItem(jobName)
    
    if (job == null) {
        job = instance.createProject(WorkflowJob.class, jobName)
        
        def scm = new GitSCM("https://github.com/Gagan261011/devops-lab.git")
        scm.branches = [new BranchSpec("*/main")]
        
        def definition = new CpsScmFlowDefinition(scm, "jenkins/Jenkinsfile")
        definition.setLightweight(false)
        
        job.setDefinition(definition)
        job.setDescription("Full CI/CD pipeline")
        job.save()
        
        println "✓ Pipeline job created"
    } else {
        println "Job already exists"
    }
} catch (Exception e) {
    println "Job creation: " + e.getMessage()
}

instance.save()
println "✓ Setup complete!"
GROOVYEOF

# Replace IPs
sed -i "s/NEXUS_IP_PLACEHOLDER/$NEXUS_IP/g" /tmp/setup-all.groovy
sed -i "s/SONAR_IP_PLACEHOLDER/$SONAR_IP/g" /tmp/setup-all.groovy

# Copy to init.groovy.d so it runs on next restart
sudo mkdir -p /var/lib/jenkins/init.groovy.d/
sudo cp /tmp/setup-all.groovy /var/lib/jenkins/init.groovy.d/setup.groovy
sudo chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/setup.groovy

# Restart Jenkins to execute
echo "Restarting Jenkins to apply configuration..."
sudo systemctl restart jenkins

echo ""
echo "Waiting for Jenkins to start..."
sleep 30

echo "✓ Setup complete! You can now login with admin/Admin123!"
