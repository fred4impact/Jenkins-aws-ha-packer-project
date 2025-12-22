#!/bin/bash
set -e

# Update system
sudo yum update -y

# Install Java
JAVA_VERSION=${JAVA_VERSION:-17}
if [ "$JAVA_VERSION" = "17" ]; then
    # Install Amazon Corretto 17 (Amazon's distribution of OpenJDK)
    # Add Corretto repository if not already present
    if [ ! -f /etc/yum.repos.d/corretto.repo ]; then
        sudo wget -O /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
    fi
    sudo yum install -y java-17-amazon-corretto java-17-amazon-corretto-devel
elif [ "$JAVA_VERSION" = "11" ]; then
    # Install Amazon Corretto 11 (available in default repos on AL2)
    sudo yum install -y java-11-amazon-corretto java-11-amazon-corretto-devel
else
    # Fallback to standard OpenJDK for other versions
    sudo yum install -y java-${JAVA_VERSION}-openjdk java-${JAVA_VERSION}-openjdk-devel
fi

# Verify Java installation
java -version

# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Install EFS utilities
sudo yum install -y amazon-efs-utils

# Install Jenkins
JENKINS_VERSION=${JENKINS_VERSION:-2.414.3}
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum install -y jenkins-${JENKINS_VERSION}

# Install required plugins (will be configured on first boot)
sudo mkdir -p /var/lib/jenkins/plugins
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U ./amazon-cloudwatch-agent.rpm
rm amazon-cloudwatch-agent.rpm

# Install SSM Agent (usually pre-installed, but ensure it's running)
sudo systemctl enable amazon-ssm-agent

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
sudo yum clean all
sudo rm -rf /tmp/*

echo "Jenkins installation completed successfully"

