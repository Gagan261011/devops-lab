#!/bin/bash

echo "========================================="
echo "Complete End-to-End DevOps Lab Setup"
echo "========================================="

# SonarQube Configuration
echo ""
echo "=== Configuring SonarQube ==="
echo "Changing admin password..."
curl -s -u admin:admin -X POST "http://localhost:9000/api/users/change_password?login=admin&previousPassword=admin&password=Admin123!" || echo "Password already changed"

echo "Generating Jenkins token..."
sleep 2
TOKEN_RESPONSE=$(curl -s -u admin:Admin123! -X POST "http://localhost:9000/api/user_tokens/generate?name=jenkins-token")
SONAR_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SONAR_TOKEN" ]; then
    echo "Checking if token already exists..."
    SONAR_TOKEN=$(curl -s -u admin:Admin123! "http://localhost:9000/api/user_tokens/search" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

if [ -n "$SONAR_TOKEN" ]; then
    echo "✓ SonarQube token: $SONAR_TOKEN"
    echo "$SONAR_TOKEN" > /tmp/sonar-token.txt
else
    echo "✗ Failed to get token, using placeholder"
    echo "squ_32be2ae49596ad9e35e1291497e9f718e61fc6ab" > /tmp/sonar-token.txt
    SONAR_TOKEN="squ_32be2ae49596ad9e35e1291497e9f718e61fc6ab"
fi

echo "✓ SonarQube configured!"
