variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS"
  default     = null
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Enable deletion protection for ALB"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

