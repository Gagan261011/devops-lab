#!/bin/bash
set -e

# Nexus Repository Manager Installation and Configuration Script

echo "=== Starting Nexus Installation ==="
exec > >(tee -a /var/log/nexus-install.log)
exec 2>&1

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install Java 8 (Nexus 3 works well with Java 8)
apt-get install -y openjdk-8-jdk wget tar

# Create nexus user
useradd -r -m -U -d /opt/nexus -s /bin/bash nexus

# Download and install Nexus
NEXUS_VERSION="3.60.0-02"
cd /tmp

echo "Downloading Nexus ${NEXUS_VERSION}..."
# Retry logic for download
for i in {1..5}; do
  if wget -q --show-progress "https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz"; then
    echo "Download successful!"
    break
  else
    echo "Download attempt $i failed, retrying in 10 seconds..."
    sleep 10
  fi
done

if [ ! -f "nexus-${NEXUS_VERSION}-unix.tar.gz" ]; then
  echo "ERROR: Failed to download Nexus after 5 attempts"
  exit 1
fi

echo "Extracting Nexus..."
tar -xzf "nexus-${NEXUS_VERSION}-unix.tar.gz"
mv "nexus-${NEXUS_VERSION}" /opt/nexus/nexus
mv sonatype-work /opt/nexus/ 2>/dev/null || true

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

# Configure Nexus automatically
if [ -n "$NEXUS_ADMIN_PASSWORD" ]; then
  echo "=== Configuring Nexus ==="
  
  # Create configuration script
  cat > /opt/nexus/configure.sh << 'CONFIGSCRIPT'
#!/bin/bash

# Wait a bit more for Nexus API to be ready
sleep 60

INITIAL_PASS=$(cat /opt/nexus/sonatype-work/nexus3/admin.password 2>/dev/null)

if [ -n "$INITIAL_PASS" ]; then
  echo "Changing admin password..."
  curl -s -u admin:$INITIAL_PASS -X PUT "http://localhost:8081/service/rest/v1/security/users/admin/change-password" \
    -H "Content-Type: text/plain" \
    -d "Admin123!" || echo "Password already changed"
  
  sleep 5
  
  # Disable anonymous access
  curl -s -u admin:Admin123! -X PUT "http://localhost:8081/service/rest/v1/security/anonymous" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}' || true
  
  echo "Nexus configured successfully"
  
  # Store credentials
  cat > /opt/nexus/credentials.txt << 'CREDS'
username=admin
password=Admin123!
CREDS
  chmod 644 /opt/nexus/credentials.txt
fi
CONFIGSCRIPT

  chmod +x /opt/nexus/configure.sh
  chown nexus:nexus /opt/nexus/configure.sh
  
  # Run configuration in background
  nohup su - nexus -c "/opt/nexus/configure.sh" > /var/log/nexus-config.log 2>&1 &
fi

echo "=== Nexus Configuration Started ==="
echo "Nexus will be available at http://<server-ip>:8081"
echo "Credentials: admin / Admin123!"
echo "Configuration running in background..."
