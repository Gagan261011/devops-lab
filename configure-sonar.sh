#!/bin/bash
# Configure SonarQube

echo "Changing SonarQube admin password..."
curl -u admin:admin -X POST "http://localhost:9000/api/users/change_password?login=admin&previousPassword=admin&password=Admin123!"

echo -e "\n\nGenerating SonarQube token for Jenkins..."
RESPONSE=$(curl -u admin:Admin123! -X POST "http://localhost:9000/api/user_tokens/generate?name=jenkins-token")
echo "$RESPONSE"

TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo -e "\n\nSonarQube Token: $TOKEN"
echo "Save this token - you'll need it for Jenkins!"
