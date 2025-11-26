#!/bin/bash
# Complete Jenkins Configuration Fix - Install plugins, apply JCasC, create job

set -e

echo "=== Comprehensive Jenkins Fix ==="

# Stop Jenkins
sudo systemctl stop jenkins
sleep 10

# Ensure directories exist
sudo mkdir -p /var/lib/jenkins/casc_configs
sudo mkdir -p /var/lib/jenkins/plugins
sudo mkdir -p /var/lib/jenkins/init.groovy.d

# Copy JCasC configuration
if [ -f "/opt/devops-lab/jenkins/jenkins-casc.yaml" ]; then
    echo "Setting up JCasC configuration..."
    sudo cp /opt/devops-lab/jenkins/jenkins-casc.yaml /var/lib/jenkins/casc_configs/
    
    # Replace all placeholders with actual values
    sudo sed -i "s|SONAR_URL_PLACEHOLDER|http://44.204.1.68:9000|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    sudo sed -i "s|NEXUS_URL_PLACEHOLDER|http://54.172.116.75:8081|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    sudo sed -i "s|ANSIBLE_MASTER_IP_PLACEHOLDER|98.93.233.250|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    sudo sed -i "s|GITHUB_REPO_PLACEHOLDER|https://github.com/Gagan261011/devops-lab.git|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
fi

# Download and install required plugins
echo "Installing Jenkins plugins..."
JENKINS_HOME=/var/lib/jenkins
PLUGIN_DIR=$JENKINS_HOME/plugins
JENKINS_UC=https://updates.jenkins.io

# Core plugins needed
PLUGINS=(
    "configuration-as-code"
    "job-dsl"
    "git"
    "git-client"
    "workflow-aggregator"
    "workflow-job"
    "workflow-cps"
    "pipeline-stage-view"
    "credentials"
    "credentials-binding"
    "ssh-credentials"
    "ssh-agent"
    "plain-credentials"
    "sonar"
    "maven-plugin"
    "nexus-artifact-uploader"
    "ansible"
    "ansicolor"
    "junit"
    "ssh"
)

for plugin in "${PLUGINS[@]}"; do
    if [ ! -f "$PLUGIN_DIR/${plugin}.jpi" ]; then
        echo "Downloading ${plugin}..."
        sudo curl -L -s "$JENKINS_UC/latest/${plugin}.hpi" -o "$PLUGIN_DIR/${plugin}.jpi" 2>/dev/null || echo "Failed to download ${plugin}"
    fi
done

# Create groovy script to setup admin user and disable wizard
sudo tee /var/lib/jenkins/init.groovy.d/01-setup.groovy > /dev/null << 'GROOVYEOF'
#!groovy
import jenkins.model.*
import hudson.security.*
import jenkins.install.*

def instance = Jenkins.getInstance()

// Disable setup wizard
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

// Create admin user
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "Admin123!")
instance.setSecurityRealm(hudsonRealm)

// Set authorization strategy
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
println("Admin user created and security configured")
GROOVYEOF

# Create job DSL script to create pipeline
sudo tee /var/lib/jenkins/init.groovy.d/02-create-job.groovy > /dev/null << 'JOBEOF'
#!groovy
import jenkins.model.*
import hudson.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.GitSCM
import hudson.plugins.git.BranchSpec

def jenkins = Jenkins.getInstance()

// Create pipeline job
def jobName = "java-crud-ci-cd"
def job = jenkins.getItem(jobName)

if (job == null) {
    println("Creating job: ${jobName}")
    
    job = jenkins.createProject(WorkflowJob, jobName)
    job.setDescription("Full CI/CD pipeline for Java CRUD application")
    
    // Configure SCM
    def scm = new GitSCM("https://github.com/Gagan261011/devops-lab.git")
    scm.branches = [new BranchSpec("*/main"), new BranchSpec("*/master")]
    
    // Set pipeline from SCM
    def definition = new CpsScmFlowDefinition(scm, "jenkins/Jenkinsfile")
    definition.setLightweight(true)
    job.setDefinition(definition)
    
    job.save()
    println("Job ${jobName} created successfully")
} else {
    println("Job ${jobName} already exists")
}

jenkins.save()
JOBEOF

# Set ownership
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Start Jenkins
echo "Starting Jenkins..."
sudo systemctl start jenkins

echo "=== Jenkins Configuration Complete ==="
echo "Wait 2-3 minutes for Jenkins to fully start and load configuration"
echo "The pipeline job 'java-crud-ci-cd' should be created automatically"
echo "Login: admin / Admin123!"
