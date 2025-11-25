#!/bin/bash
set -e

# Ansible Slave Configuration Script

echo "=== Starting Ansible Slave Configuration ==="

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install basic packages
apt-get install -y python3 python3-pip openssh-server sudo

# Ensure SSH is running
systemctl enable ssh
systemctl start ssh

# Configure ubuntu user SSH access
mkdir -p /home/ubuntu/.ssh
chown ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh

# Add Ansible master's public key to authorized_keys
cat > /home/ubuntu/.ssh/authorized_keys << 'PUBLICKEY'
${ansible_public_key}
PUBLICKEY

chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys

# Ensure ubuntu user has sudo privileges
usermod -aG sudo ubuntu
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 440 /etc/sudoers.d/ubuntu

echo "=== Ansible Slave Configuration Complete ==="
echo "Ready to accept connections from Ansible master"
