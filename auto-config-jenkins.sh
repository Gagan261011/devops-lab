#!/bin/bash

SONAR_TOKEN="$1"
SONAR_IP="$2"
NEXUS_IP="$3"

echo "Step 3/4: Configuring Jenkins..."
echo "--------------------------------"

# Create comprehensive Jenkins configuration script
cat > /tmp/jenkins-config.groovy << GROOVYEOF
import jenkins.model.*
import hudson.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.plugins.sshslaves.*
import hudson.plugins.sonar.*
import hudson.plugins.sonar.model.TriggersConfig

def instance = Jenkins.getInstance()

// 1. Configure Global Environment Variables
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

envVars.put("NEXUS_URL", "${NEXUS_IP}:8081")
envVars.put("SONAR_HOST_URL", "http://${SONAR_IP}:9000")

instance.save()
println "✓ Environment variables configured"

// 2. Configure Credentials
def domain = Domain.global()
def store = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

// SonarQube Token
def sonarToken = new StringCredentialsImpl(
  CredentialsScope.GLOBAL,
  "sonar-token",
  "SonarQube authentication token",
  Secret.fromString("${SONAR_TOKEN}")
)

def existingSonar = store.getCredentials(domain).find { it.id == "sonar-token" }
if (existingSonar) {
  store.updateCredentials(domain, existingSonar, sonarToken)
  println "✓ Updated SonarQube token"
} else {
  store.addCredentials(domain, sonarToken)
  println "✓ Created SonarQube token"
}

// Nexus Credentials
def nexusCreds = new UsernamePasswordCredentialsImpl(
  CredentialsScope.GLOBAL,
  "nexus-credentials",
  "Nexus Repository credentials",
  "admin",
  "Admin123!"
)

def existingNexus = store.getCredentials(domain).find { it.id == "nexus-credentials" }
if (!existingNexus) {
  store.addCredentials(domain, nexusCreds)
  println "✓ Created Nexus credentials"
} else {
  println "✓ Nexus credentials exist"
}

// Ansible SSH Key
if (new File('/var/lib/jenkins/ansible_key.pem').exists()) {
  def sshKey = new BasicSSHUserPrivateKey(
    CredentialsScope.GLOBAL,
    "ansible-ssh-key",
    "ubuntu",
    new BasicSSHUserPrivateKey.FileOnMasterPrivateKeySource('/var/lib/jenkins/ansible_key.pem'),
    "",
    "SSH key for Ansible deployments"
  )
  
  def existingSSH = store.getCredentials(domain).find { it.id == "ansible-ssh-key" }
  if (!existingSSH) {
    store.addCredentials(domain, sshKey)
    println "✓ Created Ansible SSH key"
  } else {
    println "✓ Ansible SSH key exists"
  }
}

// 3. Configure SonarQube Server
def sonarDesc = instance.getDescriptor("hudson.plugins.sonar.SonarGlobalConfiguration")
if (sonarDesc != null) {
  def sonarInst = new SonarInstallation(
    "SonarQube",
    "http://${SONAR_IP}:9000",
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
}

// 4. Configure Maven
def mavenDesc = instance.getDescriptor("hudson.tasks.Maven")
if (mavenDesc != null) {
  def mavenInstaller = new hudson.tasks.Maven.MavenInstaller("3.9.5")
  def mavenInstallation = new hudson.tasks.Maven.MavenInstallation(
    "Maven-3.9",
    "",
    [new hudson.tools.InstallSourceProperty([mavenInstaller])]
  )
  mavenDesc.setInstallations(mavenInstallation)
  mavenDesc.save()
  println "✓ Maven configured"
}

// 5. Configure JDK
def jdkDesc = instance.getDescriptor("hudson.model.JDK")
if (jdkDesc != null) {
  def jdk = new hudson.model.JDK("JDK-17", "/usr/lib/jvm/java-17-openjdk-amd64")
  jdkDesc.setInstallations(jdk)
  jdkDesc.save()
  println "✓ JDK configured"
}

instance.save()
println ""
println "========================================="
println "✓ Jenkins fully configured!"
println "========================================="
GROOVYEOF

# Execute the Groovy script
curl -s -u admin:Admin123! --data-urlencode "script@/tmp/jenkins-config.groovy" http://localhost:8080/scriptText

echo ""
echo "✓ Jenkins configuration complete"
