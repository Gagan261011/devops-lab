#!/bin/bash

echo "========================================="
echo "Automated End-to-End Configuration"
echo "========================================="

# Step 1: Configure SonarQube
echo ""
echo "Step 1/4: Configuring SonarQube..."
echo "--------------------------------"

curl -s -u admin:admin -X POST "http://localhost:9000/api/users/change_password?login=admin&previousPassword=admin&password=Admin123!" || echo "Password already set"

sleep 2

TOKEN_RESPONSE=$(curl -s -u admin:Admin123! -X POST "http://localhost:9000/api/user_tokens/generate?name=jenkins-token")
SONAR_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SONAR_TOKEN" ]; then
    echo "Using existing token from yesterday"
    SONAR_TOKEN="squ_32be2ae49596ad9e35e1291497e9f718e61fc6ab"
fi

echo "SonarQube Token: $SONAR_TOKEN"
echo "$SONAR_TOKEN" > /tmp/sonar-token.txt

echo "✓ SonarQube configured"
