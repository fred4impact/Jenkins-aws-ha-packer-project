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

  provisioner "file" {
    source      = "../jenkins-config/"
    destination = "/tmp/jenkins-config"
  }

  provisioner "shell" {
    script = "scripts/install-jenkins.sh"
  }

  provisioner "ansible" {
    playbook_file = "../playbooks/jenkins-setup.yml"
    user          = "ubuntu"
    extra_arguments = [
      "--extra-vars", "jenkins_version=${var.jenkins_version}",
      "--extra-vars", "java_version=${var.java_version}",
      "--extra-vars", "jenkins_home=/var/lib/jenkins",
      "-v"
    ]
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_SSH_ARGS='-o IdentitiesOnly=yes'"
    ]
  }

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

