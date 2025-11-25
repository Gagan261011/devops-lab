variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "key_pair_name" {
  description = "Name of existing AWS key pair for SSH access"
  type        = string
}

variable "my_ip" {
  description = "Your public IP address for SSH access (CIDR format, e.g., 1.2.3.4/32)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-lab"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ubuntu_ami" {
  description = "Ubuntu 22.04 AMI ID (leave empty for auto-lookup)"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository URL for the project"
  type        = string
  default     = "https://github.com/YOUR_USERNAME/devops-lab.git"
}
