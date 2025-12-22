terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configure backend in backend.tf or via CLI
    # bucket = "demo-terra-state-bucket"
    # key    = "ha-jenkins/terraform.tfstate"
    # region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source to get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "../modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = data.aws_availability_zones.available.names

  tags = local.common_tags
}

# Security Group for Jenkins Instances
resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Security group for Jenkins instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Jenkins HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [module.elb.alb_security_group_id]
  }

  ingress {
    description = "SSH from bastion or VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-jenkins-sg"
    }
  )
}

# EFS Module
module "efs" {
  source = "../modules/efs"

  project_name               = var.project_name
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  jenkins_security_group_ids = [aws_security_group.jenkins.id]
  enable_backup              = var.enable_efs_backup
  kms_key_id                 = var.efs_kms_key_id

  tags = local.common_tags
}

# ELB Module
module "elb" {
  source = "../modules/elb"

  project_name               = var.project_name
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  certificate_arn            = var.acm_certificate_arn
  enable_deletion_protection = var.enable_deletion_protection

  tags = local.common_tags
}

# ASG Module
module "asg" {
  source = "../modules/asg"

  project_name       = var.project_name
  ami_id             = var.jenkins_ami_id
  instance_type      = var.instance_type
  key_name           = var.key_name
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.jenkins.id]
  target_group_arns  = [module.elb.target_group_arn]
  efs_id             = module.efs.efs_id
  efs_dns_name       = module.efs.efs_dns_name
  min_size           = var.asg_min_size
  max_size           = var.asg_max_size
  desired_capacity   = var.asg_desired_capacity
  volume_size        = var.volume_size
  region             = var.aws_region
  jenkins_admin_user = var.jenkins_admin_user
  jenkins_admin_pass = var.jenkins_admin_pass

  tags = local.common_tags
}

# S3 Bucket for Jenkins Artifacts
resource "aws_s3_bucket" "jenkins_artifacts" {
  bucket = "${var.project_name}-jenkins-artifacts-${random_id.bucket_suffix.hex}"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-jenkins-artifacts"
    }
  )
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  rule {
    id     = "delete-old-artifacts"
    status = "Enabled"

    expiration {
      days = var.artifact_retention_days
    }
  }
}

