#!/bin/bash
set -e

# Nexus Repository Manager Installation and Configuration Script

echo "=== Starting Nexus Installation ==="

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install Java 8 (Nexus 3 works well with Java 8)
apt-get install -y openjdk-8-jdk wget

# Create nexus user
useradd -r -m -U -d /opt/nexus -s /bin/bash nexus

# Download and install Nexus
NEXUS_VERSION=3.60.0-02
cd /tmp
wget https://download.sonatype.com/nexus/3/nexus-$${NEXUS_VERSION}-unix.tar.gz
tar -xvzf nexus-$${NEXUS_VERSION}-unix.tar.gz
mv nexus-$${NEXUS_VERSION} /opt/nexus/nexus
mv sonatype-work /opt/nexus/

# Set ownership
chown -R nexus:nexus /opt/nexus

# Configure Nexus to run as nexus user
echo "run_as_user=\"nexus\"" > /opt/nexus/nexus/bin/nexus.rc

# Create systemd service
cat > /etc/systemd/system/nexus.service << 'EOF'
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
EOF

# Start Nexus
systemctl daemon-reload
systemctl enable nexus
systemctl start nexus

echo "=== Waiting for Nexus to start (this may take 2-3 minutes) ==="
sleep 150

# Wait for Nexus to be healthy
for i in {1..30}; do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 | grep -q "200\|303"; then
    echo "Nexus is up and running"
    break
  fi
  echo "Waiting for Nexus... attempt $i/30"
  sleep 10
done

# Get initial admin password
NEXUS_ADMIN_PASSWORD=""
if [ -f "/opt/nexus/sonatype-work/nexus3/admin.password" ]; then
  NEXUS_ADMIN_PASSWORD=$(cat /opt/nexus/sonatype-work/nexus3/admin.password)
  echo "Initial admin password: $NEXUS_ADMIN_PASSWORD"
fi

# Wait a bit more for Nexus to be fully ready
sleep 30

# Change admin password using API
if [ -n "$NEXUS_ADMIN_PASSWORD" ]; then
  echo "=== Configuring Nexus ==="
  
  # Change admin password
  curl -u admin:$NEXUS_ADMIN_PASSWORD -X PUT "http://localhost:8081/service/rest/v1/security/users/admin/change-password" \
    -H "Content-Type: text/plain" \
    -d "Admin123!" || true
  
  sleep 5
  
  # Disable anonymous access
  curl -u admin:Admin123! -X PUT "http://localhost:8081/service/rest/v1/security/anonymous" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}' || true
  
  # Create maven-releases repository if it doesn't exist (usually exists by default)
  echo "Maven repositories (maven-releases, maven-snapshots) are created by default"
  
  # Store credentials for reference
  cat > /opt/nexus/credentials.txt << 'CREDS'
username=admin
password=Admin123!
CREDS
  chmod 644 /opt/nexus/credentials.txt
fi

echo "=== Nexus Configuration Complete ==="
echo "Nexus is available at http://<server-ip>:8081"
echo "Default credentials: admin / Admin123!"
echo "Maven repo: http://<server-ip>:8081/repository/maven-releases/"
