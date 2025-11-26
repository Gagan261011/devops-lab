#!/bin/bash

echo "=== Fixing Jenkins Startup Issue ==="

# Remove JCasC from startup temporarily
echo "Updating systemd override..."
cat > /etc/systemd/system/jenkins.service.d/override.conf << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
EOF

# Reload systemd
systemctl daemon-reload

# Reset failed state
systemctl reset-failed jenkins

# Start Jenkins
echo "Starting Jenkins..."
systemctl start jenkins

# Wait for startup
echo "Waiting for Jenkins to start..."
sleep 30

# Check status
systemctl status jenkins --no-pager

echo ""
echo "If Jenkins is running, you can access it at http://<server-ip>:8080"
echo "Login with: admin / Admin123!"
