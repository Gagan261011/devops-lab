#!/bin/bash
# Fix Jenkins Configuration - Skip Setup Wizard and Apply JCasC

echo "=== Fixing Jenkins Configuration ==="

# Stop Jenkins
sudo systemctl stop jenkins
sleep 5

# Skip the setup wizard by creating the config file
sudo mkdir -p /var/lib/jenkins
echo "2.0" | sudo tee /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion > /dev/null
echo "2.0" | sudo tee /var/lib/jenkins/jenkins.install.UpgradeWizard.state > /dev/null

# Create JCasC directory if not exists
sudo mkdir -p /var/lib/jenkins/casc_configs
sudo chown jenkins:jenkins /var/lib/jenkins/casc_configs

# Update Jenkins service configuration to load JCasC and skip wizard
sudo tee /etc/default/jenkins > /dev/null << 'JENKINSCONFIG'
# defaults for Jenkins automation server

# pulled in from the init script; makes things easier.
NAME=jenkins

# arguments to pass to java

# Allow graphs etc. to work even when an X server is present
JAVA_ARGS="-Djava.awt.headless=true"

#JAVA_ARGS="-Xmx256m"

# make jenkins listen on IPv4 address
#JAVA_ARGS="-Djava.net.preferIPv4Stack=true"

JENKINS_ARGS="--webroot=/var/cache/$NAME/war --httpPort=$HTTP_PORT"

# Disable setup wizard and load JCasC
JAVA_ARGS="$JAVA_ARGS -Djenkins.install.runSetupWizard=false -Dcasc.jenkins.config=/var/lib/jenkins/casc_configs/jenkins-casc.yaml"
JENKINSCONFIG

# Copy JCasC configuration if it exists
if [ -f "/opt/devops-lab/jenkins/jenkins-casc.yaml" ]; then
    echo "Copying JCasC configuration..."
    sudo cp /opt/devops-lab/jenkins/jenkins-casc.yaml /var/lib/jenkins/casc_configs/
    sudo chown jenkins:jenkins /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    
    # Get actual IPs and URLs from environment
    JENKINS_IP=$(hostname -I | awk '{print $1}')
    
    # Replace placeholders
    sudo sed -i "s|SONAR_URL_PLACEHOLDER|http://44.204.1.68:9000|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    sudo sed -i "s|NEXUS_URL_PLACEHOLDER|http://54.172.116.75:8081|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    sudo sed -i "s|ANSIBLE_MASTER_IP_PLACEHOLDER|98.93.233.250|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
    sudo sed -i "s|GITHUB_REPO_PLACEHOLDER|https://github.com/Gagan261011/devops-lab.git|g" /var/lib/jenkins/casc_configs/jenkins-casc.yaml
fi

# Install essential plugins manually using Jenkins CLI
echo "Installing essential plugins..."
sudo mkdir -p /var/lib/jenkins/plugins

# Download plugin installation script
cat > /tmp/install-plugins.sh << 'PLUGINSCRIPT'
#!/bin/bash
JENKINS_HOME=/var/lib/jenkins
PLUGIN_DIR=$JENKINS_HOME/plugins
JENKINS_UC=https://updates.jenkins.io

mkdir -p $PLUGIN_DIR

# Essential plugins
PLUGINS=(
    "configuration-as-code:latest"
    "job-dsl:latest"
    "git:latest"
    "workflow-aggregator:latest"
    "credentials:latest"
    "credentials-binding:latest"
    "ssh-credentials:latest"
    "sonar:latest"
    "maven-plugin:latest"
    "ansible:latest"
)

for plugin in "${PLUGINS[@]}"; do
    name=$(echo $plugin | cut -d: -f1)
    echo "Downloading $name..."
    curl -L "$JENKINS_UC/latest/${name}.hpi" -o "$PLUGIN_DIR/${name}.jpi" 2>/dev/null || true
done

chown -R jenkins:jenkins $PLUGIN_DIR
PLUGINSCRIPT

sudo bash /tmp/install-plugins.sh

# Start Jenkins
echo "Starting Jenkins..."
sudo systemctl start jenkins

echo "=== Jenkins Fix Complete ==="
echo "Jenkins should now be accessible without setup wizard"
echo "Default credentials: admin / Admin123!"
echo "Wait 2-3 minutes for Jenkins to start..."
