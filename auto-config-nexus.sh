#!/bin/bash

echo "Step 2/4: Configuring Nexus..."
echo "--------------------------------"

if [ -f "/opt/nexus/sonatype-work/nexus3/admin.password" ]; then
    INITIAL_PASS=$(sudo cat /opt/nexus/sonatype-work/nexus3/admin.password)
    
    curl -s -u admin:$INITIAL_PASS -X PUT "http://localhost:8081/service/rest/v1/security/users/admin/change-password" \
      -H "Content-Type: text/plain" -d "Admin123!" || echo "Password already set"
    
    curl -s -u admin:Admin123! -X PUT "http://localhost:8081/service/rest/v1/security/anonymous" \
      -H "Content-Type: application/json" -d '{"enabled":false}' || true
else
    echo "Using existing configuration"
fi

echo "✓ Nexus configured"
