output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.jenkins.id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.jenkins.dns_name
}

output "efs_security_group_id" {
  description = "Security group ID for EFS"
  value       = aws_security_group.efs.id
}

