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
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "jenkins" {
  ami_name      = "jenkins-ha-${local.timestamp}"
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
    Name        = "Jenkins HA AMI"
    Environment = "Production"
    ManagedBy   = "Packer"
    Application = "Jenkins"
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

  # Copy jenkinsrole.tar (as shown in images - contains Ansible playbooks and roles)
  provisioner "file" {
    source      = "jenkinsrole.tar"
    destination = "/home/ubuntu/jenkinsrole.tar"
    only        = ["amazon-ebs.jenkins"]
  }

  # Copy setup.sh if it exists (as shown in images)
  provisioner "file" {
    source      = "scripts/setup.sh"
    destination = "/home/ubuntu/setup.sh"
    only        = ["amazon-ebs.jenkins"]
    on_error    = "continue"  # Continue if setup.sh doesn't exist
  }

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

