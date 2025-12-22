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
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "ec2-user"
  tags = {
    Name        = "Jenkins HA AMI"
    Environment = "Production"
    ManagedBy   = "Packer"
    Application = "Jenkins"
  }
}

build {
  name = "BILARN-JENKINS-AMI"
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

  # Ansible provisioner - Temporarily disabled to allow AMI build to complete
  # Jenkins configuration can be done after AMI is built and instances are launched
  # Uncomment below to enable Ansible configuration during AMI build
  # provisioner "ansible" {
  #   playbook_file = "../playbooks/jenkins-setup.yml"
  #   user          = "ec2-user"
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
      "sudo systemctl enable amazon-ssm-agent",
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

