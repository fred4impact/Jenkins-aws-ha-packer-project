# EFS Security Group
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from Jenkins instances"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = var.jenkins_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-efs-sg"
    }
  )
}

# EFS File System
resource "aws_efs_file_system" "jenkins" {
  creation_token                  = "${var.project_name}-jenkins-efs"
  performance_mode                = "generalPurpose"
  throughput_mode                 = "bursting"
  encrypted                       = true
  kms_key_id                      = var.kms_key_id
  provisioned_throughput_in_mibps = var.provisioned_throughput

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-jenkins-efs"
    }
  )
}

# EFS Mount Targets
resource "aws_efs_mount_target" "jenkins" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.jenkins.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# EFS Backup Policy
resource "aws_efs_backup_policy" "jenkins" {
  file_system_id = aws_efs_file_system.jenkins.id

  backup_policy {
    status = var.enable_backup ? "ENABLED" : "DISABLED"
  }
}

