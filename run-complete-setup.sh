#!/bin/bash

# Master orchestration script - runs everything automatically
# Usage: bash run-complete-setup.sh

set -e

echo "========================================="
echo "AUTOMATED DEVOPS LAB SETUP"
echo "========================================="

# Get IPs from terraform
cd terraform
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
SONAR_IP=$(terraform output -raw sonarqube_public_ip)
NEXUS_IP=$(terraform output -raw nexus_public_ip)
cd ..

echo ""
echo "Server IPs:"
echo "  Jenkins:   $JENKINS_IP"
echo "  SonarQube: $SONAR_IP"
echo "  Nexus:     $NEXUS_IP"
echo ""

# Wait for services to be ready
echo "Checking if services are ready..."
echo ""

for i in {1..60}; do
  JENKINS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$JENKINS_IP:8080 || echo "000")
  SONAR_STATUS=$(curl -s http://$SONAR_IP:9000/api/system/status 2>/dev/null | grep -o '"status":"UP"' || echo "down")
  NEXUS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$NEXUS_IP:8081 || echo "000")
  
  if [ "$JENKINS_STATUS" = "403" ] || [ "$JENKINS_STATUS" = "200" ]; then
    JENKINS_READY="✓"
  else
    JENKINS_READY="⏳"
  fi
  
  if [ "$SONAR_STATUS" != "down" ]; then
    SONAR_READY="✓"
  else
    SONAR_READY="⏳"
  fi
  
  if [ "$NEXUS_STATUS" = "200" ] || [ "$NEXUS_STATUS" = "303" ]; then
    NEXUS_READY="✓"
  else
    NEXUS_READY="⏳"
  fi
  
  echo "Status: Jenkins $JENKINS_READY | SonarQube $SONAR_READY | Nexus $NEXUS_READY"
  
  if [ "$JENKINS_READY" = "✓" ] && [ "$SONAR_READY" = "✓" ] && [ "$NEXUS_READY" = "✓" ]; then
    echo ""
    echo "✓ All services are ready!"
    break
  fi
  
  if [ $i -eq 60 ]; then
    echo ""
    echo "⚠ Timeout waiting for services. Proceeding anyway..."
  fi
  
  sleep 10
done

echo ""
echo "========================================="
echo "Configuring Services..."
echo "========================================="

# Configure SonarQube
echo ""
echo "▶ Configuring SonarQube..."
ssh -i my-test.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$SONAR_IP 'bash -s' < auto-config-sonar.sh
SONAR_TOKEN=$(ssh -i my-test.pem -o StrictHostKeyChecking=no ubuntu@$SONAR_IP 'cat /tmp/sonar-token.txt')

# Configure Nexus
echo ""
echo "▶ Configuring Nexus..."
ssh -i my-test.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$NEXUS_IP 'sudo bash -s' < auto-config-nexus.sh

# Configure Jenkins
echo ""
echo "▶ Configuring Jenkins..."
ssh -i my-test.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$JENKINS_IP "bash -s" < auto-config-jenkins.sh "$SONAR_TOKEN" "$SONAR_IP" "$NEXUS_IP"

echo ""
echo "Step 4/4: Updating repository on Jenkins..."
echo "--------------------------------"
ssh -i my-test.pem -o StrictHostKeyChecking=no ubuntu@$JENKINS_IP << 'UPDATEREPO'
cd /opt/devops-lab
sudo -u jenkins git fetch
sudo -u jenkins git reset --hard origin/main
echo "✓ Repository updated"
UPDATEREPO

echo ""
echo "========================================="
echo "✓ SETUP COMPLETE!"
echo "========================================="
echo ""
echo "Access URLs:"
echo "  Jenkins:   http://$JENKINS_IP:8080"
echo "  SonarQube: http://$SONAR_IP:9000"
echo "  Nexus:     http://$NEXUS_IP:8081"
echo ""
echo "Credentials (all services):"
echo "  Username: admin"
echo "  Password: Admin123!"
echo ""
echo "Next Steps:"
echo "  1. Open Jenkins: http://$JENKINS_IP:8080"
echo "  2. Login with admin / Admin123!"
echo "  3. Click on 'java-crud-ci-cd' job"
echo "  4. Click 'Build Now'"
echo "  5. Watch the pipeline execute!"
echo ""
echo "========================================="
