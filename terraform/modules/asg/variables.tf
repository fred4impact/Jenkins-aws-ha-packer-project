variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for Jenkins instances (built with Packer)"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair name"
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for ASG"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for Jenkins instances"
}

variable "target_group_arns" {
  type        = list(string)
  description = "Target group ARNs for ALB"
}

variable "efs_id" {
  type        = string
  description = "EFS file system ID"
}

variable "efs_dns_name" {
  type        = string
  description = "EFS DNS name"
}

variable "min_size" {
  type        = number
  description = "Minimum number of instances"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of instances"
  default     = 5
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of instances"
  default     = 2
}

variable "volume_size" {
  type        = number
  description = "Root volume size in GB"
  default     = 30
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "jenkins_admin_user" {
  type        = string
  description = "Jenkins admin username"
  default     = "admin"
  sensitive   = true
}

variable "jenkins_admin_pass" {
  type        = string
  description = "Jenkins admin password"
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

