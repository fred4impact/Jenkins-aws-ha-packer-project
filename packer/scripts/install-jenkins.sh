#!/bin/bash
set -e

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Enable universe and multiverse repositories (may contain additional dependencies)
sudo add-apt-repository -y universe || true
sudo add-apt-repository -y multiverse || true
sudo apt-get update -y

# Install essential build tools and dependencies first
sudo apt-get install -y \
    wget \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    unzip \
    git \
    binutils \
    software-properties-common \
    apt-transport-https

# Install Java
JAVA_VERSION=${JAVA_VERSION:-17}
if [ "$JAVA_VERSION" = "17" ]; then
    # Install OpenJDK 17 on Ubuntu
    sudo apt-get install -y openjdk-17-jdk openjdk-17-jre
elif [ "$JAVA_VERSION" = "11" ]; then
    # Install OpenJDK 11
    sudo apt-get install -y openjdk-11-jdk openjdk-11-jre
else
    # Fallback to standard OpenJDK for other versions
    sudo apt-get install -y openjdk-${JAVA_VERSION}-jdk openjdk-${JAVA_VERSION}-jre
fi

# Verify Java installation
java -version

# Install Docker
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
# EFS utils require stunnel4, Rust compiler, and other dependencies
EFS_UTILS_INSTALLED=false

echo "Installing dependencies for EFS utils..."
sudo apt-get install -y \
    stunnel4 \
    nfs-common \
    build-essential \
    pkg-config \
    libssl-dev \
    curl \
    ca-certificates

# Install Rust and Cargo (required to build efs-proxy component)
echo "Installing Rust and Cargo..."
# Install Rust using rustup for the ubuntu user (Packer's default user)
sudo -u ubuntu bash << 'RUST_INSTALL'
export HOME=/home/ubuntu
export USER=ubuntu
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUST_INSTALL

# Add cargo to PATH for subsequent commands
export PATH="/home/ubuntu/.cargo/bin:$PATH"

# Verify cargo is available
if ! command -v cargo &> /dev/null; then
    echo "Cargo not in PATH, trying to source it..."
    if [ -f /home/ubuntu/.cargo/env ]; then
        source /home/ubuntu/.cargo/env
        export PATH="/home/ubuntu/.cargo/bin:$PATH"
    fi
    
    # Final fallback: install from apt
    if ! command -v cargo &> /dev/null; then
        echo "Installing Rust from apt as fallback..."
        sudo apt-get install -y rustc cargo
    fi
fi

# Verify installation
if ! cargo --version &> /dev/null; then
    echo "Error: Cargo installation failed. Cannot build EFS utils."
    echo "Continuing without EFS utils - they can be installed later if needed."
else
    echo "Cargo installed successfully: $(cargo --version)"
    
    # Clone and build EFS utils
    echo "Building EFS utils..."
    git clone https://github.com/aws/efs-utils /tmp/efs-utils || {
        echo "Failed to clone EFS utils repository"
        EFS_UTILS_INSTALLED=false
    }
    
    if [ "$EFS_UTILS_INSTALLED" != "false" ]; then
        cd /tmp/efs-utils
        
        # Ensure cargo is available for the build script
        export PATH="/home/ubuntu/.cargo/bin:$PATH"
        export HOME=/home/ubuntu
        
        # Build EFS utils
        if ./build-deb.sh; then
            # Install the built package
            if ls ./build/amazon-efs-utils*.deb 1> /dev/null 2>&1; then
                sudo apt-get install -y ./build/amazon-efs-utils*.deb && {
                    echo "EFS utils installed successfully"
                    EFS_UTILS_INSTALLED=true
                } || {
                    echo "Failed to install EFS utils package"
                    EFS_UTILS_INSTALLED=false
                }
            else
                echo "Error: EFS utils .deb package not found after build"
                EFS_UTILS_INSTALLED=false
            fi
        else
            echo "EFS utils build failed"
            EFS_UTILS_INSTALLED=false
        fi
        
        cd /
        rm -rf /tmp/efs-utils
    fi
fi

# Summary
if [ "$EFS_UTILS_INSTALLED" = "true" ]; then
    echo "EFS utils installation completed successfully"
else
    echo "Warning: EFS utils were not installed. This is optional."
    echo "EFS can still be mounted manually using the mount.efs command."
    echo "You can install EFS utils later if needed."
fi

# Install Jenkins
JENKINS_VERSION=${JENKINS_VERSION:-2.414.3}

# Add Jenkins repository key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins repository
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package list
sudo apt-get update -y

# Install common dependencies that Jenkins might need
sudo apt-get install -y \
    fontconfig \
    fonts-dejavu-core \
    libfontconfig1 \
    libfreetype6 \
    || true

# Try to install libharfbuzz0b (package name may vary by Ubuntu version)
# Ubuntu 22.04 might use libharfbuzz0b or libharfbuzz0t64
sudo apt-get install -y libharfbuzz0b 2>/dev/null || \
    sudo apt-get install -y libharfbuzz0t64 2>/dev/null || \
    echo "libharfbuzz package not found, continuing..."

# libpcsclite1 might not be available in Ubuntu 22.04
# This is typically for smart card support which Jenkins doesn't strictly need
# We'll let apt handle this dependency automatically

# Install Jenkins
# Install without version pinning first to let apt resolve all dependencies automatically
# This avoids the libpcsclite1 dependency issue
echo "Installing Jenkins (latest available version to resolve dependencies)..."

# Install Jenkins - let apt handle dependency resolution
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jenkins || {
    echo "Jenkins installation encountered issues, attempting to resolve..."
    
    # Try to install any missing dependencies
    sudo apt-get install -y libpcsclite1 2>/dev/null || \
        sudo apt-get install -y libpcsclite1:i386 2>/dev/null || \
        echo "Note: libpcsclite1 not available (optional dependency)"
    
    # Fix any broken package states
    sudo apt-get install -f -y
    
    # Retry Jenkins installation
    echo "Retrying Jenkins installation..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jenkins
}

# If a specific version was requested and different from default, try to install it
# Note: Version pinning may fail if dependencies aren't available for that version
if [ -n "${JENKINS_VERSION}" ]; then
    CURRENT_VERSION=$(dpkg -l | grep jenkins | awk '{print $3}' | head -1 | cut -d'-' -f1)
    REQUESTED_VERSION=$(echo "${JENKINS_VERSION}" | cut -d'-' -f1)
    
    if [ "${CURRENT_VERSION}" != "${REQUESTED_VERSION}" ]; then
        echo "Attempting to install requested version ${JENKINS_VERSION}..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jenkins=${JENKINS_VERSION} || {
            echo "Warning: Could not install version ${JENKINS_VERSION}, keeping current version"
            echo "This is usually fine - Jenkins is backward compatible"
        }
    fi
fi

# Final dependency fix
sudo apt-get install -f -y || true

# Verify Jenkins installation
INSTALLED_VERSION=$(dpkg -l | grep jenkins | awk '{print $3}' | head -1)
if [ -n "${INSTALLED_VERSION}" ]; then
    echo "Jenkins successfully installed: ${INSTALLED_VERSION}"
else
    echo "Error: Jenkins installation verification failed"
    exit 1
fi

# Verify Jenkins installation
if [ -f /usr/share/jenkins/jenkins.war ] || [ -d /usr/share/jenkins ]; then
    echo "Jenkins installed successfully"
    # Show installed version
    if [ -f /usr/share/jenkins/jenkins.war ]; then
        echo "Jenkins WAR file location: /usr/share/jenkins/jenkins.war"
    fi
else
    echo "Error: Jenkins installation failed"
    exit 1
fi

# Install required plugins (will be configured on first boot)
sudo mkdir -p /var/lib/jenkins/plugins
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb || sudo apt-get install -f -y
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

