#!/bin/bash
set -e

# Ansible Master Installation and Configuration Script

echo "=== Starting Ansible Master Configuration ==="

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install Ansible, Git, and SSH
apt-get install -y ansible git openssh-client python3-pip

# Install additional Python packages for Ansible
pip3 install boto3 botocore

# Configure SSH for ubuntu user
mkdir -p /home/ubuntu/.ssh
chown ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh

# Create SSH key pair for Ansible (using the key from Terraform)
cat > /home/ubuntu/.ssh/id_rsa << 'PRIVATEKEY'
${ansible_private_key}
PRIVATEKEY

cat > /home/ubuntu/.ssh/id_rsa.pub << 'PUBLICKEY'
${ansible_public_key}
PUBLICKEY

# Set proper permissions
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa.pub
chmod 600 /home/ubuntu/.ssh/id_rsa
chmod 644 /home/ubuntu/.ssh/id_rsa.pub

# Configure SSH client to not do strict host key checking (lab environment only)
cat > /home/ubuntu/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
chown ubuntu:ubuntu /home/ubuntu/.ssh/config
chmod 600 /home/ubuntu/.ssh/config

# Clone the project repository
mkdir -p /opt/devops-lab
cd /opt/devops-lab

# Retry logic for git clone
for i in {1..5}; do
  if git clone ${github_repo} . 2>/dev/null || git pull 2>/dev/null; then
    echo "Repository cloned/updated successfully"
    break
  else
    echo "Attempt $i failed, waiting 30 seconds..."
    sleep 30
  fi
done

# Set ownership
chown -R ubuntu:ubuntu /opt/devops-lab

# Configure Ansible
mkdir -p /etc/ansible
cat > /etc/ansible/ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
inventory = /opt/devops-lab/ansible/inventory.ini
remote_user = ubuntu
private_key_file = /home/ubuntu/.ssh/id_rsa
roles_path = /opt/devops-lab/ansible/roles
retry_files_enabled = False

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF

# Create a script to test Ansible connectivity
cat > /home/ubuntu/test-ansible.sh << 'EOF'
#!/bin/bash
echo "Testing Ansible connectivity..."
cd /opt/devops-lab
ansible all -m ping
EOF
chmod +x /home/ubuntu/test-ansible.sh
chown ubuntu:ubuntu /home/ubuntu/test-ansible.sh

echo "=== Ansible Master Configuration Complete ==="
echo "SSH key pair created for passwordless access"
echo "Test connectivity with: sudo su - ubuntu -c '/home/ubuntu/test-ansible.sh'"
