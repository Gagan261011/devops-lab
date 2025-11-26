# Jenkins Server
resource "aws_instance" "jenkins" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.jenkins.id]

  user_data = templatefile("${path.module}/../cloud-init/jenkins.sh", {
    github_repo         = var.github_repo
    sonar_url           = "http://${aws_instance.sonar.private_ip}:9000"
    nexus_url           = "http://${aws_instance.nexus.private_ip}:8081"
    ansible_master_ip   = aws_instance.ansible_master.private_ip
    ansible_private_key = local.ansible_private_key
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-jenkins"
    Role = "jenkins"
  })

  depends_on = [
    aws_instance.sonar,
    aws_instance.nexus,
    aws_instance.ansible_master
  ]
}

# SonarQube Server
resource "aws_instance" "sonar" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.sonar.id]

  user_data = file("${path.module}/../cloud-init/sonar.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sonar"
    Role = "sonar"
  })
}

# Nexus Server
resource "aws_instance" "nexus" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.nexus.id]

  user_data = file("${path.module}/../cloud-init/nexus.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nexus"
    Role = "nexus"
  })
}

# Ansible Master
resource "aws_instance" "ansible_master" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ansible_master.id]

  user_data = templatefile("${path.module}/../cloud-init/ansible_master.sh", {
    ansible_private_key = local.ansible_private_key
    ansible_public_key  = local.ansible_public_key
    github_repo         = var.github_repo
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ansible-master"
    Role = "ansible-master"
  })
}

# Ansible Slave
resource "aws_instance" "ansible_slave" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ansible_slave.id]

  user_data = templatefile("${path.module}/../cloud-init/ansible_slave.sh", {
    ansible_public_key = local.ansible_public_key
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ansible-slave"
    Role = "ansible-slave"
  })
}

# Application Server
resource "aws_instance" "app_server" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app_server.id]

  user_data = templatefile("${path.module}/../cloud-init/app_server.sh", {
    ansible_public_key = local.ansible_public_key
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-app-server"
    Role = "app-server"
  })
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../ansible/inventory.ini.tpl", {
    ansible_slave_ip   = aws_instance.ansible_slave.private_ip
    app_server_ip      = aws_instance.app_server.private_ip
    nexus_ip           = aws_instance.nexus.private_ip
    jenkins_public_ip  = aws_instance.jenkins.public_ip
  })
  filename = "${path.module}/../ansible/inventory.ini"
}

# Generate infrastructure IPs JSON file for Jenkins to read
resource "local_file" "infrastructure_ips" {
  content = jsonencode({
    app_server_private_ip   = aws_instance.app_server.private_ip
    app_server_public_ip    = aws_instance.app_server.public_ip
    nexus_private_ip        = aws_instance.nexus.private_ip
    nexus_public_ip         = aws_instance.nexus.public_ip
    sonarqube_private_ip    = aws_instance.sonar.private_ip
    sonarqube_public_ip     = aws_instance.sonar.public_ip
    jenkins_public_ip       = aws_instance.jenkins.public_ip
  })
  filename = "${path.module}/../infrastructure-ips.json"
}
