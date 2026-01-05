variable "project_name" {
  type        = string
  description = "Project name for resource naming"
  default     = "ha-jenkins"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "prod"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "jenkins_ami_id" {
  type        = string
  description = "AMI ID for Jenkins instances (built with Packer). Leave empty to build automatically."
  default     = ""
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key for Packer build (optional, can use IAM role)"
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key for Packer build (optional, can use IAM role)"
  default     = ""
  sensitive   = true
}

variable "build_ami_with_packer" {
  type        = bool
  description = "Whether to build AMI with Packer (true) or use existing AMI ID (false)"
  default     = true
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for Jenkins"
  default     = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair name for SSH access"
  default     = null
}

variable "asg_min_size" {
  type        = number
  description = "Minimum number of Jenkins instances"
  default     = 2
}

variable "asg_max_size" {
  type        = number
  description = "Maximum number of Jenkins instances"
  default     = 5
}

variable "asg_desired_capacity" {
  type        = number
  description = "Desired number of Jenkins instances"
  default     = 2
}

variable "volume_size" {
  type        = number
  description = "Root volume size in GB"
  default     = 30
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS (optional)"
  default     = null
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Enable deletion protection for ALB"
  default     = false
}

variable "enable_efs_backup" {
  type        = bool
  description = "Enable EFS backup"
  default     = true
}

variable "efs_kms_key_id" {
  type        = string
  description = "KMS key ID for EFS encryption (optional)"
  default     = null
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH to Jenkins instances"
  default     = []
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

variable "artifact_retention_days" {
  type        = number
  description = "Number of days to retain Jenkins artifacts in S3"
  default     = 90
}

variable "jenkins_version" {
  type        = string
  description = "Jenkins version to install (used when building AMI with Packer)"
  default     = "2.414.3"
}

variable "java_version" {
  type        = string
  description = "Java version to install (used when building AMI with Packer)"
  default     = "17"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources"
  default     = {}
}

