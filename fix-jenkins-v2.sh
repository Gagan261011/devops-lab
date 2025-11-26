#!/bin/bash
# Properly fix Jenkins to skip setup wizard

echo "=== Fixing Jenkins Systemd Service ==="

# Stop Jenkins
sudo systemctl stop jenkins
sleep 5

# Create the skip setup wizard markers
sudo mkdir -p /var/lib/jenkins
echo "2.0" | sudo tee /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion
echo "2.0" | sudo tee /var/lib/jenkins/jenkins.install.UpgradeWizard.state
sudo touch /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

# Backup original service file
sudo cp /lib/systemd/system/jenkins.service /lib/systemd/system/jenkins.service.backup

# Create new service file with proper JAVA_OPTS
sudo tee /lib/systemd/system/jenkins.service > /dev/null << 'SERVICEEOF'
[Unit]
Description=Jenkins Continuous Integration Server
Requires=network.target
After=network.target

[Service]
Type=notify
NotifyAccess=main
ExecStart=/usr/bin/java -Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -Dcasc.jenkins.config=/var/lib/jenkins/casc_configs/jenkins-casc.yaml -jar /usr/share/java/jenkins.war --webroot=/var/cache/jenkins/war --httpPort=8080
Restart=on-failure
SuccessExitStatus=143
User=jenkins
Group=jenkins

# The Java process is forked by the wrapper script, so use this to wait
TimeoutStartSec=180
StandardOutput=journal
StandardError=journal
SyslogIdentifier=jenkins

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Reload systemd
sudo systemctl daemon-reload

# Create JCasC config directory
sudo mkdir -p /var/lib/jenkins/casc_configs
sudo chown -R jenkins:jenkins /var/lib/jenkins/casc_configs

# Copy JCasC if exists
if [ -f "/opt/devops-lab/jenkins/jenkins-casc.yaml" ]; then
    sudo cp /opt/devops-lab/jenkins/jenkins-casc.yaml /var/lib/jenkins/casc_configs/
    sudo chown jenkins:jenkins /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    
    # Replace placeholders with actual values
    sudo sed -i "s|SONAR_URL_PLACEHOLDER|http://44.204.1.68:9000|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    sudo sed -i "s|NEXUS_URL_PLACEHOLDER|http://54.172.116.75:8081|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml  
    sudo sed -i "s|ANSIBLE_MASTER_IP_PLACEHOLDER|98.93.233.250|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    sudo sed -i "s|GITHUB_REPO_PLACEHOLDER|https://github.com/Gagan261011/devops-lab.git|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
fi

# Set ownership
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Start Jenkins
sudo systemctl start jenkins

echo "=== Fix Complete ===" 
echo "Jenkins restarting with setup wizard disabled..."
echo "Wait 1-2 minutes and refresh your browser"
echo "Login with: admin / Admin123!"
