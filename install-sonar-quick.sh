#!/bin/bash
# Quick install SonarQube

set -e
cd /tmp

echo "Installing SonarQube..."
SONAR_VERSION="9.9.3.79811"

# Download SonarQube
wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip

# Extract and install
unzip -q sonarqube-${SONAR_VERSION}.zip
sudo mkdir -p /opt/sonarqube
sudo mv sonarqube-${SONAR_VERSION} /opt/sonarqube/sonarqube
sudo useradd -r -m -U -d /opt/sonarqube -s /bin/bash sonarqube 2>/dev/null || true
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# System limits
sudo bash -c 'cat >> /etc/security/limits.conf' << EOF
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOF

sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536

# Systemd service
sudo tee /etc/systemd/system/sonarqube.service > /dev/null << 'SVCEOF'
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
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

echo "SonarQube started. Wait 2-3 minutes for it to be ready on port 9000"
