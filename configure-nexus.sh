#!/bin/bash

echo "=== Configuring Nexus ==="

# Get initial password
if [ -f "/opt/nexus/sonatype-work/nexus3/admin.password" ]; then
    INITIAL_PASS=$(sudo cat /opt/nexus/sonatype-work/nexus3/admin.password)
    echo "Initial password found"
    
    # Change password
    echo "Changing admin password..."
    curl -s -u admin:$INITIAL_PASS -X PUT "http://localhost:8081/service/rest/v1/security/users/admin/change-password" \
      -H "Content-Type: text/plain" \
      -d "Admin123!" || echo "Password already changed"
    
    # Disable anonymous access
    curl -s -u admin:Admin123! -X PUT "http://localhost:8081/service/rest/v1/security/anonymous" \
      -H "Content-Type: application/json" \
      -d '{"enabled":false}' || true
    
    echo "✓ Nexus configured!"
else
    echo "⚠ Nexus not fully initialized yet, password already set or using Admin123!"
fi
