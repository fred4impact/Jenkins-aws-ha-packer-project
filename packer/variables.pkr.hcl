variable "aws_region" {
  type        = string
  description = "AWS region for AMI creation"
  default     = "us-east-1"
}

variable "jenkins_version" {
  type        = string
  description = "Jenkins version to install"
  default     = "2.414.3"
}

variable "java_version" {
  type        = string
  description = "Java version to install"
  default     = "17"
}

variable "efs_id" {
  type        = string
  description = "EFS File System ID (passed from Terraform)"
  default     = ""
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key (optional, can use IAM role)"
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key (optional, can use IAM role)"
  default     = ""
  sensitive   = true
}

variable "build_number" {
  type        = string
  description = "Build number or identifier for AMI naming (e.g., from CI/CD pipeline)"
  default     = ""
}

