#!/bin/bash
set -e

# SonarQube Installation and Configuration Script

echo "=== Starting SonarQube Installation ==="
exec > >(tee -a /var/log/sonarqube-install.log)
exec 2>&1

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install Java 17 (required for SonarQube)
apt-get install -y openjdk-17-jdk unzip curl wget

# Create sonarqube user
useradd -r -m -U -d /opt/sonarqube -s /bin/bash sonarqube

# Download and install SonarQube
SONAR_VERSION="9.9.3.79811"
cd /tmp

echo "Downloading SonarQube ${SONAR_VERSION}..."
# Retry logic for download
for i in {1..5}; do
  if wget -q --show-progress "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip"; then
    echo "Download successful!"
    break
  else
    echo "Download attempt $i failed, retrying in 10 seconds..."
    sleep 10
  fi
done

if [ ! -f "sonarqube-${SONAR_VERSION}.zip" ]; then
  echo "ERROR: Failed to download SonarQube after 5 attempts"
  exit 1
fi

echo "Extracting SonarQube..."
unzip -q "sonarqube-${SONAR_VERSION}.zip"
mv "sonarqube-${SONAR_VERSION}" /opt/sonarqube/sonarqube
chown -R sonarqube:sonarqube /opt/sonarqube

# Configure system limits
cat >> /etc/security/limits.conf << EOF
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOF

cat >> /etc/sysctl.conf << EOF
vm.max_map_count=262144
fs.file-max=65536
EOF
sysctl -p

# Create systemd service
cat > /etc/systemd/system/sonarqube.service << 'EOF'
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Start SonarQube
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

echo "=== Waiting for SonarQube to start (this may take 2-3 minutes) ==="
sleep 120

# Wait for SonarQube to be healthy
for i in {1..30}; do
  if curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
    echo "SonarQube is up and running"
    break
  fi
  echo "Waiting for SonarQube... attempt $i/30"
  sleep 10
done

# Configure SonarQube automatically
echo "=== Configuring SonarQube ==="

# Create configuration script that runs after SonarQube is fully up
cat > /opt/sonarqube/configure.sh << 'CONFIGSCRIPT'
#!/bin/bash

# Wait for SonarQube to be fully ready
for i in {1..60}; do
  STATUS=$(curl -s http://localhost:9000/api/system/status | grep -o '"status":"UP"')
  if [ -n "$STATUS" ]; then
    echo "SonarQube is ready"
    break
  fi
  echo "Waiting for SonarQube to be ready... $i/60"
  sleep 10
done

# Change admin password
echo "Changing admin password..."
curl -s -u admin:admin -X POST "http://localhost:9000/api/users/change_password?login=admin&previousPassword=admin&password=Admin123!" || echo "Password already changed"

sleep 5

# Generate token for Jenkins
echo "Generating Jenkins token..."
TOKEN_RESPONSE=$(curl -s -u admin:Admin123! -X POST "http://localhost:9000/api/user_tokens/generate?name=jenkins-token")
SONAR_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$SONAR_TOKEN" ]; then
  echo "Token generated: $SONAR_TOKEN"
  echo "$SONAR_TOKEN" > /opt/sonarqube/jenkins-token.txt
  chmod 644 /opt/sonarqube/jenkins-token.txt
fi

echo "SonarQube configuration complete"
CONFIGSCRIPT

chmod +x /opt/sonarqube/configure.sh
chown sonarqube:sonarqube /opt/sonarqube/configure.sh

# Run configuration in background
nohup su - sonarqube -c "/opt/sonarqube/configure.sh" > /var/log/sonarqube-config.log 2>&1 &

echo "=== SonarQube Configuration Started ==="
echo "SonarQube will be available at http://<server-ip>:9000"
echo "Credentials: admin / Admin123!"
echo "Configuration running in background..."
