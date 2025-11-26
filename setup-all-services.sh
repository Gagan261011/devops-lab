#!/bin/bash

echo "========================================="
echo "Complete DevOps Lab Configuration"
echo "========================================="

# Get server IPs
JENKINS_IP="34.203.244.5"
SONAR_IP="44.201.175.118"
NEXUS_IP="13.221.225.72"

echo ""
echo "Step 1: Configuring SonarQube..."
echo "--------------------------------"

ssh -i my-test.pem -o StrictHostKeyChecking=no ubuntu@$SONAR_IP << 'SONAR_EOF'
echo "Changing SonarQube admin password..."
curl -s -u admin:admin -X POST "http://localhost:9000/api/users/change_password?login=admin&previousPassword=admin&password=Admin123!" 2>/dev/null || echo "Password already changed"

echo "Generating SonarQube token..."
sleep 2
TOKEN_RESPONSE=$(curl -s -u admin:Admin123! -X POST "http://localhost:9000/api/user_tokens/generate?name=jenkins-token" 2>/dev/null)
SONAR_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SONAR_TOKEN" ]; then
    SONAR_TOKEN="squ_32be2ae49596ad9e35e1291497e9f718e61fc6ab"
fi

echo "$SONAR_TOKEN"
SONAR_EOF

echo "✓ SonarQube configured"

echo ""
echo "Step 2: Configuring Nexus..."
echo "--------------------------------"

ssh -i my-test.pem -o StrictHostKeyChecking=no ubuntu@$NEXUS_IP << 'NEXUS_EOF'
if [ -f "/opt/nexus/sonatype-work/nexus3/admin.password" ]; then
    INITIAL_PASS=$(sudo cat /opt/nexus/sonatype-work/nexus3/admin.password)
    curl -s -u admin:$INITIAL_PASS -X PUT "http://localhost:8081/service/rest/v1/security/users/admin/change-password" \
      -H "Content-Type: text/plain" -d "Admin123!" 2>/dev/null || echo "Password already changed"
    echo "✓ Nexus password set"
else
    echo "✓ Nexus already configured"
fi
NEXUS_EOF

echo "✓ Nexus configured"

echo ""
echo "Step 3: Configuring Jenkins Credentials..."
echo "--------------------------------"

SONAR_TOKEN="squ_32be2ae49596ad9e35e1291497e9f718e61fc6ab"

ssh -i my-test.pem -o StrictHostKeyChecking=no ubuntu@$JENKINS_IP << JENKINS_EOF
# Create Groovy script to update credentials
sudo tee /tmp/update-creds.groovy > /dev/null << 'GROOVY_SCRIPT'
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.plugins.sshslaves.*

def instance = Jenkins.getInstance()
def domain = Domain.global()
def store = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

// SonarQube token
def sonarToken = new StringCredentialsImpl(
  CredentialsScope.GLOBAL,
  "sonar-token",
  "SonarQube authentication token",
  Secret.fromString("${SONAR_TOKEN}")
)

def existing = store.getCredentials(domain).findAll { it.id == "sonar-token" }
if (existing) {
  store.updateCredentials(domain, existing[0], sonarToken)
} else {
  store.addCredentials(domain, sonarToken)
}

// Nexus credentials
def nexusCreds = new UsernamePasswordCredentialsImpl(
  CredentialsScope.GLOBAL,
  "nexus-credentials",
  "Nexus Repository credentials",
  "admin",
  "Admin123!"
)

existing = store.getCredentials(domain).findAll { it.id == "nexus-credentials" }
if (!existing) {
  store.addCredentials(domain, nexusCreds)
}

// Ansible SSH key
if (new File('/var/lib/jenkins/ansible_key.pem').exists()) {
  def sshKey = new BasicSSHUserPrivateKey(
    CredentialsScope.GLOBAL,
    "ansible-ssh-key",
    "ubuntu",
    new BasicSSHUserPrivateKey.FileOnMasterPrivateKeySource('/var/lib/jenkins/ansible_key.pem'),
    "",
    "SSH key for Ansible deployments"
  )
  
  existing = store.getCredentials(domain).findAll { it.id == "ansible-ssh-key" }
  if (!existing) {
    store.addCredentials(domain, sshKey)
  }
}

instance.save()
println "Credentials configured successfully"
GROOVY_SCRIPT

# Execute the script
curl -s -u admin:Admin123! --data-urlencode "script@/tmp/update-creds.groovy" http://localhost:8080/scriptText
JENKINS_EOF

echo "✓ Jenkins credentials configured"

echo ""
echo "========================================="
echo "✓ SETUP COMPLETE!"
echo "========================================="
echo ""
echo "All services configured:"
echo "  Jenkins:   http://$JENKINS_IP:8080"
echo "  SonarQube: http://$SONAR_IP:9000"
echo "  Nexus:     http://$NEXUS_IP:8081"
echo ""
echo "Credentials: admin / Admin123!"
echo ""
echo "Next: Open Jenkins and run the pipeline!"
echo "========================================="
