packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

locals {
  # Format: YYYYMMDD
  build_date = formatdate("YYYYMMDD", timestamp())
  # Format: HHMMSS
  build_time = formatdate("HHMMSS", timestamp())
  # Full timestamp for unique naming
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  # AMI name format: Jenkins-bilarn-HA-AMI-YYYYMMDD-BUILD-NUMBER
  ami_name_base = "Jenkins-bilarn-HA-AMI-${local.build_date}"
  # If build_number is provided, use it; otherwise use timestamp
  ami_name = var.build_number != "" ? "${local.ami_name_base}-${var.build_number}" : "${local.ami_name_base}-${local.timestamp}"
}

source "amazon-ebs" "jenkins" {
  ami_name      = local.ami_name
  instance_type = "t3.medium"
  region        = var.aws_region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]  # Canonical (Ubuntu)
  }
  ssh_username = "ubuntu"
  tags = {
    Name        = local.ami_name
    Environment = "Production"
    ManagedBy   = "Packer"
    Application = "Jenkins"
    BuildDate   = local.build_date
    BuildTime   = local.build_time
    BuildNumber = var.build_number != "" ? var.build_number : local.timestamp
  }
}

build {
  name = "jenkins-ha-ami"
  sources = [
    "source.amazon-ebs.jenkins"
  ]

  # Copy Jenkins configuration files
  provisioner "file" {
    source      = "../jenkins-config/"
    destination = "/tmp/jenkins-config"
  }

  # Note: jenkinsrole.tar and setup.sh are optional files
  # They will be handled in shell provisioner if they exist in the build environment

  # Install Jenkins and base software
  provisioner "shell" {
    script = "scripts/install-jenkins.sh"
  }

  # Extract jenkinsrole.tar and run setup.sh with EFS ID (as shown in images)
  provisioner "shell" {
    inline = [
      "cd /home/ubuntu",
      "if [ -f jenkinsrole.tar ]; then tar -xvf jenkinsrole.tar; fi",
      # Store EFS ID for later use (during instance launch)
      "if [ -n '${var.efs_id}' ]; then echo 'EFS_ID=${var.efs_id}' | sudo tee /opt/jenkins/efs-id.txt; fi",
      # Run setup.sh with EFS ID if it exists
      "if [ -f setup.sh ]; then chmod +x setup.sh && ./setup.sh '${var.efs_id}'; fi"
    ]
  }

  # Ansible provisioner - Temporarily disabled to allow AMI build to complete
  # Jenkins configuration can be done after AMI is built and instances are launched
  # Uncomment below to enable Ansible configuration during AMI build
  # provisioner "ansible" {
  #   playbook_file = "../playbooks/jenkins-setup.yml"
  #   user          = "ubuntu"
  #   extra_arguments = [
  #     "--extra-vars", "jenkins_version=${var.jenkins_version}",
  #     "--extra-vars", "java_version=${var.java_version}",
  #     "--extra-vars", "jenkins_home=/var/lib/jenkins",
  #     "-v"
  #   ]
  #   ansible_env_vars = [
  #     "ANSIBLE_HOST_KEY_CHECKING=False",
  #     "ANSIBLE_SSH_ARGS='-o IdentitiesOnly=yes'"
  #   ]
  # }

  provisioner "shell" {
    inline = [
      "sudo systemctl enable jenkins",
      "sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service || sudo systemctl enable amazon-ssm-agent",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker jenkins",
      "sudo mkdir -p /opt/jenkins",
      "sudo chown jenkins:jenkins /opt/jenkins"
    ]
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
}

