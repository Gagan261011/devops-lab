output "jenkins_url" {
  description = "Jenkins server URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_public_ip" {
  description = "Jenkins server public IP"
  value       = aws_instance.jenkins.public_ip
}

output "sonarqube_url" {
  description = "SonarQube server URL"
  value       = "http://${aws_instance.sonar.public_ip}:9000"
}

output "sonarqube_public_ip" {
  description = "SonarQube server public IP"
  value       = aws_instance.sonar.public_ip
}

output "nexus_url" {
  description = "Nexus server URL"
  value       = "http://${aws_instance.nexus.public_ip}:8081"
}

output "nexus_public_ip" {
  description = "Nexus server public IP"
  value       = aws_instance.nexus.public_ip
}

output "ansible_master_ip" {
  description = "Ansible master public IP"
  value       = aws_instance.ansible_master.public_ip
}

output "ansible_slave_ip" {
  description = "Ansible slave public IP"
  value       = aws_instance.ansible_slave.public_ip
}

output "app_server_url" {
  description = "Application server URL"
  value       = "http://${aws_instance.app_server.public_ip}:8080"
}

output "app_server_public_ip" {
  description = "Application server public IP"
  value       = aws_instance.app_server.public_ip
}

output "app_server_private_ip" {
  description = "Application server private IP"
  value       = aws_instance.app_server.private_ip
}

output "nexus_private_ip" {
  description = "Nexus server private IP"
  value       = aws_instance.nexus.private_ip
}

output "sonarqube_private_ip" {
  description = "SonarQube server private IP"
  value       = aws_instance.sonar.private_ip
}

output "credentials" {
  description = "Default credentials (for lab use only)"
  value = {
    jenkins_user     = "admin"
    jenkins_password = "Admin123!"
    sonar_user       = "admin"
    sonar_password   = "Admin123!"
    nexus_user       = "admin"
    nexus_password   = "Admin123!"
  }
  sensitive = true
}

output "ssh_commands" {
  description = "SSH commands to access servers"
  value = {
    jenkins        = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.jenkins.public_ip}"
    sonar          = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.sonar.public_ip}"
    nexus          = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.nexus.public_ip}"
    ansible_master = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.ansible_master.public_ip}"
    ansible_slave  = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.ansible_slave.public_ip}"
    app_server     = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.app_server.public_ip}"
  }
}

output "next_steps" {
  description = "Next steps after Terraform apply"
  value = <<-EOT
    
    ========================================
    DEVOPS LAB SETUP COMPLETE!
    ========================================
    
    Jenkins:   ${aws_instance.jenkins.public_ip}:8080
    SonarQube: ${aws_instance.sonar.public_ip}:9000
    Nexus:     ${aws_instance.nexus.public_ip}:8081
    App:       ${aws_instance.app_server.public_ip}:8080
    
    Credentials (all services):
      Username: admin
      Password: Admin123!
    
    Wait ~5-10 minutes for all services to start and configure.
    
    Next Steps:
    1. Open Jenkins: http://${aws_instance.jenkins.public_ip}:8080
    2. Login with admin / Admin123!
    3. Run the pipeline job: java-crud-ci-cd
    4. Monitor the build process
    5. Access the app: http://${aws_instance.app_server.public_ip}:8080/health
    
    To destroy: terraform destroy
    ========================================
  EOT
}
