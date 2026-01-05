#!/bin/bash
set -e

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Java
JAVA_VERSION=${JAVA_VERSION:-17}
sudo apt-get install -y openjdk-${JAVA_VERSION}-jdk openjdk-${JAVA_VERSION}-jre

# Install Docker
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Install EFS utilities
sudo apt-get install -y binutils
git clone https://github.com/aws/efs-utils
cd efs-utils
sudo ./build-deb.sh
sudo apt-get install -y ./build/amazon-efs-utils*.deb
cd ..
rm -rf efs-utils

# Install Jenkins
JENKINS_VERSION=${JENKINS_VERSION:-2.414.3}

# Add Jenkins repository key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins repository
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package list and install Jenkins
sudo apt-get update -y
sudo apt-get install -y jenkins=${JENKINS_VERSION}

# Install required plugins (will be configured on first boot)
sudo mkdir -p /var/lib/jenkins/plugins
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Install SSM Agent (usually pre-installed, but ensure it's running)
sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service || sudo systemctl enable amazon-ssm-agent

# Configure Jenkins directories
sudo mkdir -p /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Create Jenkins init script directory
sudo mkdir -p /opt/jenkins/init-scripts
sudo chown jenkins:jenkins /opt/jenkins/init-scripts

# Install Terraform (optional, for Jenkins agents)
TERRAFORM_VERSION="1.6.0"
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo mv terraform /usr/local/bin/
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install kubectl (optional, for Kubernetes deployments)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Clean up
sudo apt-get autoremove -y
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /tmp/*

echo "Jenkins installation completed successfully"

