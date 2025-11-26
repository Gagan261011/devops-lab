#!/bin/bash

echo "=== Configuring SonarQube server in Jenkins ===" 

SONAR_IP="3.93.220.226"

cat > /tmp/sonar-config.groovy << 'GROOVYEOF'
import jenkins.model.*
import hudson.plugins.sonar.*
import hudson.plugins.sonar.model.TriggersConfig

def instance = Jenkins.getInstance()

try {
    def sonarDesc = instance.getDescriptor("hudson.plugins.sonar.SonarGlobalConfiguration")
    
    // Simple constructor - just name, server URL, and credential ID
    def sonarInst = new SonarInstallation(
        "SonarQube",                           // name
        "http://SONAR_IP_PLACEHOLDER:9000",   // serverUrl
        "sonar-token",                         // credentialsId
        null,                                  // mojoVersion
        null,                                  // additionalProperties
        null,                                  // additionalAnalysisProperties  
        new TriggersConfig()                   // triggers
    )
    
    sonarDesc.setInstallations(sonarInst)
    sonarDesc.save()
    
    println "✓ SonarQube server configured successfully"
} catch (Exception e) {
    println "Error configuring SonarQube: " + e.getMessage()
    e.printStackTrace()
}
GROOVYEOF

sed -i "s/SONAR_IP_PLACEHOLDER/$SONAR_IP/g" /tmp/sonar-config.groovy

# Copy and restart
sudo mkdir -p /var/lib/jenkins/init.groovy.d/
sudo cp /tmp/sonar-config.groovy /var/lib/jenkins/init.groovy.d/sonar.groovy
sudo chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/sonar.groovy

echo "Restarting Jenkins..."
sudo systemctl restart jenkins

echo "Waiting for Jenkins to start..."
sleep 30

echo "✓ Done! SonarQube should now be configured"
