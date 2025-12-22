output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.elb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.elb.alb_arn
}

output "efs_id" {
  description = "EFS file system ID"
  value       = module.efs.efs_id
}

output "efs_dns_name" {
  description = "EFS DNS name"
  value       = module.efs.efs_dns_name
}

output "asg_id" {
  description = "Auto Scaling Group ID"
  value       = module.asg.asg_id
}

output "s3_bucket_name" {
  description = "S3 bucket name for Jenkins artifacts"
  value       = aws_s3_bucket.jenkins_artifacts.bucket
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${module.elb.alb_dns_name}"
}

output "jenkins_url_https" {
  description = "Jenkins HTTPS URL (if certificate is configured)"
  value       = var.acm_certificate_arn != null ? "https://${module.elb.alb_dns_name}" : null
}

