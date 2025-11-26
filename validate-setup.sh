#!/bin/bash

# Validation script to check all DevOps lab components
# Run this after terraform apply to verify everything is working

set +e  # Don't exit on errors, we want to see all results

echo "========================================="
echo "DevOps Lab Setup Validation"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if IP addresses file exists
if [ ! -f "server_ips.txt" ]; then
    echo -e "${YELLOW}Warning: server_ips.txt not found. Creating from Terraform outputs...${NC}"
    cd terraform
    terraform output > ../server_ips.txt
    cd ..
fi

# Extract IPs from terraform output
echo "Extracting server IPs..."
JENKINS_IP=$(cd terraform && terraform output -raw jenkins_public_ip 2>/dev/null)
SONAR_IP=$(cd terraform && terraform output -raw sonar_public_ip 2>/dev/null)
NEXUS_IP=$(cd terraform && terraform output -raw nexus_public_ip 2>/dev/null)
ANSIBLE_MASTER_IP=$(cd terraform && terraform output -raw ansible_master_public_ip 2>/dev/null)

echo "Jenkins: $JENKINS_IP"
echo "SonarQube: $SONAR_IP"
echo "Nexus: $NEXUS_IP"
echo "Ansible Master: $ANSIBLE_MASTER_IP"
echo ""

# Function to check HTTP service
check_service() {
    local name=$1
    local url=$2
    local expected_code=$3
    
    echo -n "Checking $name... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null)
    
    if [ "$response" = "$expected_code" ] || [ "$response" = "200" ]; then
        echo -e "${GREEN}✓ OK (HTTP $response)${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED (HTTP $response)${NC}"
        return 1
    fi
}

# Function to check SSH access
check_ssh() {
    local name=$1
    local ip=$2
    
    echo -n "Checking SSH to $name... "
    
    if [ ! -f "my-test.pem" ]; then
        echo -e "${RED}✗ SSH key (my-test.pem) not found${NC}"
        return 1
    fi
    
    if ssh -i my-test.pem -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$ip "echo 'SSH OK'" &>/dev/null; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

# Check all services
echo "========================================="
echo "Service Health Checks"
echo "========================================="

check_service "Jenkins" "http://$JENKINS_IP:8080" "200"
JENKINS_OK=$?

check_service "SonarQube" "http://$SONAR_IP:9000" "200"
SONAR_OK=$?

check_service "Nexus" "http://$NEXUS_IP:8081" "200"
NEXUS_OK=$?

echo ""
echo "========================================="
echo "SSH Connectivity Checks"
echo "========================================="

check_ssh "Jenkins" "$JENKINS_IP"
check_ssh "SonarQube" "$SONAR_IP"
check_ssh "Nexus" "$NEXUS_IP"
check_ssh "Ansible Master" "$ANSIBLE_MASTER_IP"

echo ""
echo "========================================="
echo "Configuration File Checks"
echo "========================================="

# Check if Jenkins job exists
echo -n "Checking Jenkins job configuration... "
if [ -f "my-test.pem" ]; then
    JOB_EXISTS=$(ssh -i my-test.pem -o StrictHostKeyChecking=no ubuntu@$JENKINS_IP "sudo test -d /var/lib/jenkins/jobs/java-crud-ci-cd && echo 'exists' || echo 'missing'" 2>/dev/null)
    if [ "$JOB_EXISTS" = "exists" ]; then
        echo -e "${GREEN}✓ Job exists${NC}"
    else
        echo -e "${YELLOW}⚠ Job not found (may need manual creation)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Cannot check (no SSH key)${NC}"
fi

# Check if Ansible inventory exists
echo -n "Checking Ansible inventory... "
if [ -f "ansible/inventory.ini" ]; then
    echo -e "${GREEN}✓ Found${NC}"
else
    echo -e "${RED}✗ Missing${NC}"
fi

# Check if application is built
echo -n "Checking application build... "
if [ -f "app/pom.xml" ]; then
    echo -e "${GREEN}✓ Found${NC}"
else
    echo -e "${RED}✗ Missing${NC}"
fi

echo ""
echo "========================================="
echo "Summary"
echo "========================================="

TOTAL_CHECKS=7
PASSED_CHECKS=0

[ $JENKINS_OK -eq 0 ] && ((PASSED_CHECKS++))
[ $SONAR_OK -eq 0 ] && ((PASSED_CHECKS++))
[ $NEXUS_OK -eq 0 ] && ((PASSED_CHECKS++))

echo "Passed: $PASSED_CHECKS / $TOTAL_CHECKS core checks"
echo ""

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}All critical services are running!${NC}"
    echo ""
    echo "Access URLs:"
    echo "  Jenkins:    http://$JENKINS_IP:8080 (admin/Admin123!)"
    echo "  SonarQube:  http://$SONAR_IP:9000 (admin/Admin123!)"
    echo "  Nexus:      http://$NEXUS_IP:8081 (admin/Admin123!)"
else
    echo -e "${YELLOW}Some services need attention. Check logs with:${NC}"
    echo "  ssh -i my-test.pem ubuntu@<server-ip> 'sudo tail -100 /var/log/cloud-init-output.log'"
fi

echo ""
echo "========================================="
