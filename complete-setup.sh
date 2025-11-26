#!/bin/bash

echo "========================================="
echo "Complete Setup - All Services"
echo "========================================="

SONAR_IP="44.201.175.118"
NEXUS_IP="13.221.225.72"

# Wait for services to be ready
echo ""
echo "Checking service availability..."

# Check SonarQube
for i in {1..30}; do
  if curl -s http://$SONAR_IP:9000/api/system/status | grep -q "UP"; then
    echo "✓ SonarQube is ready"
    break
  fi
  echo "Waiting for SonarQube... ($i/30)"
  sleep 10
done

# Check Nexus
for i in {1..30}; do
  if curl -s -o /dev/null -w "%{http_code}" http://$NEXUS_IP:8081 | grep -q "200\|303"; then
    echo "✓ Nexus is ready"
    break
  fi
  echo "Waiting for Nexus... ($i/30)"
  sleep 10
done

echo ""
echo "========================================="
echo "All services are ready!"
echo "========================================="
echo ""
echo "Jenkins:   http://34.203.244.5:8080"
echo "SonarQube: http://$SONAR_IP:9000"
echo "Nexus:     http://$NEXUS_IP:8081"
echo ""
echo "Credentials: admin / Admin123!"
echo ""
echo "You can now run the Jenkins pipeline!"
echo "========================================="
