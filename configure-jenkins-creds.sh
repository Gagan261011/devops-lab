#!/bin/bash

SONAR_TOKEN=$1

echo "=== Configuring Jenkins Credentials ==="

# Create credentials via Groovy script
cat > /tmp/update-credentials.groovy << 'GROOVYEOF'
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.plugins.sshslaves.*

def instance = Jenkins.getInstance()
def domain = Domain.global()
def store = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

// Update SonarQube token
def sonarToken = new StringCredentialsImpl(
  CredentialsScope.GLOBAL,
  "sonar-token",
  "SonarQube authentication token",
  Secret.fromString("SONAR_TOKEN_PLACEHOLDER")
)

// Find and update or create
def existingCreds = store.getCredentials(domain).findAll { it.id == "sonar-token" }
if (existingCreds) {
  store.updateCredentials(domain, existingCreds[0], sonarToken)
  println "✓ Updated SonarQube token"
} else {
  store.addCredentials(domain, sonarToken)
  println "✓ Created SonarQube token"
}

// Add Nexus credentials if not exists
def nexusCreds = new UsernamePasswordCredentialsImpl(
  CredentialsScope.GLOBAL,
  "nexus-credentials",
  "Nexus Repository credentials",
  "admin",
  "Admin123!"
)

def existingNexus = store.getCredentials(domain).findAll { it.id == "nexus-credentials" }
if (!existingNexus) {
  store.addCredentials(domain, nexusCreds)
  println "✓ Created Nexus credentials"
} else {
  println "✓ Nexus credentials already exist"
}

// Add SSH key for Ansible if not exists
if (new File('/var/lib/jenkins/ansible_key.pem').exists()) {
  def sshKey = new BasicSSHUserPrivateKey(
    CredentialsScope.GLOBAL,
    "ansible-ssh-key",
    "ubuntu",
    new BasicSSHUserPrivateKey.FileOnMasterPrivateKeySource('/var/lib/jenkins/ansible_key.pem'),
    "",
    "SSH key for Ansible deployments"
  )
  
  def existingSSH = store.getCredentials(domain).findAll { it.id == "ansible-ssh-key" }
  if (!existingSSH) {
    store.addCredentials(domain, sshKey)
    println "✓ Created Ansible SSH key"
  } else {
    println "✓ Ansible SSH key already exists"
  }
}

instance.save()
println "✓ All credentials configured!"
GROOVYEOF

# Replace token placeholder
sed -i "s/SONAR_TOKEN_PLACEHOLDER/$SONAR_TOKEN/g" /tmp/update-credentials.groovy

# Execute groovy script
java -jar /var/lib/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:Admin123! groovy = < /tmp/update-credentials.groovy 2>/dev/null || \
  curl -s -u admin:Admin123! --data-urlencode "script=$(</tmp/update-credentials.groovy)" http://localhost:8080/scriptText

echo "✓ Jenkins credentials updated!"
