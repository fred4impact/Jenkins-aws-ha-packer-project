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

