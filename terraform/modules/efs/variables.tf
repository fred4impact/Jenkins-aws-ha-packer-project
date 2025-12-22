variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EFS will be created"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for EFS mount targets"
}

variable "jenkins_security_group_ids" {
  type        = list(string)
  description = "Security group IDs of Jenkins instances"
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID for EFS encryption"
  default     = null
}

variable "provisioned_throughput" {
  type        = number
  description = "Provisioned throughput in MiBps"
  default     = 0
}

variable "enable_backup" {
  type        = bool
  description = "Enable EFS backup"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

