output "asg_id" {
  description = "ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.jenkins.id
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.jenkins.arn
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.jenkins.id
}

