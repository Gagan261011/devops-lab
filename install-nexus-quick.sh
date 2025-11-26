#!/bin/bash
# Quick install Nexus

set -e
cd /tmp

echo "Installing Nexus Repository..."
NEXUS_VERSION="3.60.0-02"

# Download Nexus
wget -q https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz

# Extract and install
tar -xzf nexus-${NEXUS_VERSION}-unix.tar.gz
sudo mkdir -p /opt/nexus
sudo mv nexus-${NEXUS_VERSION} /opt/nexus/nexus
sudo mv sonatype-work /opt/nexus/
sudo useradd -r -m -U -d /opt/nexus -s /bin/bash nexus 2>/dev/null || true
sudo chown -R nexus:nexus /opt/nexus

# Configure to run as nexus user
echo "run_as_user=\"nexus\"" | sudo tee /opt/nexus/nexus/bin/nexus.rc

# Systemd service
sudo tee /etc/systemd/system/nexus.service > /dev/null << 'SVCEOF'
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/nexus/bin/nexus start
ExecStop=/opt/nexus/nexus/bin/nexus stop
User=nexus
Group=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable nexus
sudo systemctl start nexus

echo "Nexus started. Wait 2-3 minutes for it to be ready on port 8081"
