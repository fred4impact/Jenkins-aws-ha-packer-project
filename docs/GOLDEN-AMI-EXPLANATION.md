# Golden AMI Build Process with HashiCorp Packer

## Overview

A **Golden AMI** (Amazon Machine Image) is a pre-configured, standardized, and hardened virtual machine image that serves as a template for launching EC2 instances. In the context of our Jenkins HA setup, the Golden AMI contains all the necessary software, configurations, and security settings required for Jenkins instances in the Auto Scaling Group.

## What is a Golden AMI?

A Golden AMI is essentially a "snapshot" of a fully configured EC2 instance that includes:
- Operating system (e.g., Ubuntu, Amazon Linux)
- Pre-installed software (Jenkins, Java, Docker, etc.)
- Security configurations and patches
- Organization-specific settings and tools
- Optimized performance settings

Instead of installing and configuring software every time a new instance launches, the Auto Scaling Group uses this pre-built AMI, resulting in:
- **Faster instance launches** (minutes instead of hours)
- **Consistency** across all instances
- **Reduced configuration drift**
- **Improved security** (pre-hardened images)

## The Packer Workflow

HashiCorp Packer automates the creation of Golden AMIs through a standardized process:

```
Base AMI → Temporary EC2 Instance → Configuration → Golden AMI
```

### Step-by-Step Process

#### 1. **Base AMI (Input)**
- **What it is**: A clean, unmodified operating system image (e.g., Ubuntu, Amazon Linux 2)
- **Purpose**: Starting point for building the Golden AMI
- **Example**: `amzn2-ami-hvm-*-x86_64-gp2` (Amazon Linux 2)

#### 2. **Temporary EC2 Instance (Build Environment)**
- **What happens**: Packer launches a temporary EC2 instance using the Base AMI
- **Purpose**: This is the "workspace" where all installations and configurations occur
- **Lifecycle**: 
  - Created at the start of the build
  - Configured with all required software
  - Terminated after the AMI is created
  - **You don't pay for this instance after it's terminated**

#### 3. **Provisioning Phase**
During this phase, Packer uses **provisioners** to configure the temporary instance:

**In our Jenkins project, we use:**
- **Shell Scripts**: Install Jenkins, Java, Docker, AWS CLI, etc.
- **File Uploads**: Copy configuration files to the instance
- **Ansible (Optional)**: For complex configuration management

**What gets installed on the temporary instance:**
- ✅ Jenkins (specific version)
- ✅ Java (JDK/JRE)
- ✅ Docker
- ✅ AWS CLI v2
- ✅ EFS utilities
- ✅ CloudWatch agent
- ✅ Terraform, kubectl (optional tools)
- ✅ Security patches and updates
- ✅ Organization-specific configurations

#### 4. **Golden AMI Creation (Output)**
- **What happens**: Packer creates a snapshot of the fully configured temporary instance
- **Result**: A new AMI ID that can be used to launch identical instances
- **Storage**: The AMI is stored in your AWS account and can be shared across regions

## Visual Workflow Diagram

```
┌─────────────┐
│  Base AMI   │
│   (Ubuntu)  │
└──────┬──────┘
       │
       │ Packer launches
       ▼
┌─────────────────────────────────────┐
│      Temporary EC2 Instance         │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ Provisioner (Ansible/Shell)   │  │
│  │                               │  │
│  │ • Install Jenkins            │  │
│  │ • Install Java               │  │
│  │ • Install Docker             │  │
│  │ • Apply Security Configs     │  │
│  │ • Run Organization Playbook  │  │
│  └───────────────────────────────┘  │
│                                     │
│  [Configured and Ready]             │
└──────┬──────────────────────────────┘
       │
       │ Packer creates snapshot
       ▼
┌─────────────┐
│ Golden AMI  │
│  (Output)   │
└─────────────┘
```

## Benefits of Using Golden AMIs

### 1. **Speed and Efficiency**
- **Without Golden AMI**: New instance takes 30-60 minutes to install and configure
- **With Golden AMI**: New instance is ready in 2-5 minutes
- **Impact**: Critical for auto-scaling scenarios where instances need to come online quickly

### 2. **Consistency**
- All instances are identical
- No configuration drift between instances
- Predictable behavior across environments

### 3. **Security**
- Pre-hardened images with security patches
- No exposure during installation phase
- Consistent security posture

### 4. **Cost Optimization**
- Reduced instance launch time = lower costs
- Fewer failed deployments = less waste
- Better resource utilization

### 5. **Compliance and Governance**
- Standardized images meet organizational requirements
- Easier auditing and compliance checks
- Version control for infrastructure

## How It Works in Our Jenkins HA Project

### In the Packer Configuration (`packer/jenkins-ami.pkr.hcl`)

```hcl
source "amazon-ebs" "jenkins" {
  source_ami_filter {
    filters = {
      name = "amzn2-ami-hvm-*-x86_64-gp2"  # Base AMI
    }
    most_recent = true
    owners      = ["amazon"]
  }
  # ... other settings
}

build {
  sources = ["source.amazon-ebs.jenkins"]
  
  # Provisioners configure the temporary instance
  provisioner "file" {
    source      = "../jenkins-config/"
    destination = "/tmp/jenkins-config/"
  }
  
  provisioner "shell" {
    script = "scripts/install-jenkins.sh"  # Installs all software
  }
  
  # Result: Golden AMI is created
}
```

### In the Terraform Configuration

The Golden AMI ID is then used in the Auto Scaling Group:

```hcl
resource "aws_launch_template" "jenkins" {
  image_id = var.jenkins_ami_id  # ← Golden AMI ID from Packer
  # ...
}
```

When the Auto Scaling Group needs to scale up:
1. It launches a new EC2 instance using the Golden AMI
2. The instance already has Jenkins, Java, Docker, etc. pre-installed
3. Only minimal configuration is needed (EFS mount, user data script)
4. Instance is ready in minutes, not hours

## Organization-Specific Customization

The Golden AMI can be customized for your organization:

### 1. **Pre-installed Tools**
- Organization-specific CLI tools
- Custom scripts and utilities
- Internal software packages

### 2. **Security Hardening**
- Security patches applied
- Firewall rules configured
- Security agents installed (e.g., CrowdStrike, Trend Micro)

### 3. **Compliance Requirements**
- CIS benchmarks applied
- Audit logging configured
- Compliance tools installed

### 4. **Performance Optimization**
- Tuned kernel parameters
- Optimized system settings
- Pre-warmed caches

## Best Practices

### 1. **Version Control**
- Tag AMIs with version numbers
- Use semantic versioning (e.g., `jenkins-ami-v1.2.3`)
- Document changes in each version

### 2. **Regular Updates**
- Rebuild AMIs monthly with security patches
- Update software versions regularly
- Test new AMIs in staging before production

### 3. **Testing**
- Validate AMIs in a test environment
- Run automated tests on new AMIs
- Verify all required software is installed

### 4. **Documentation**
- Document what's included in each AMI
- Maintain a changelog
- Keep build scripts in version control

### 5. **Security**
- Scan AMIs for vulnerabilities
- Use encrypted AMIs
- Limit AMI sharing to necessary accounts

## Example: Building a Jenkins Golden AMI

### Step 1: Define the Base AMI
```hcl
source_ami_filter {
  filters = {
    name = "amzn2-ami-hvm-*-x86_64-gp2"
  }
  most_recent = true
  owners      = ["amazon"]
}
```

### Step 2: Install Software (Provisioner)
```bash
# scripts/install-jenkins.sh
sudo yum update -y
sudo yum install -y java-17-openjdk
sudo yum install -y jenkins-2.414.3
sudo yum install -y docker
# ... more installations
```

### Step 3: Configure System
```bash
# Apply security settings
# Configure services
# Set up monitoring
```

### Step 4: Build the AMI
```bash
packer build jenkins-ami.pkr.hcl
```

### Step 5: Use the AMI
```hcl
# In Terraform
variable "jenkins_ami_id" {
  default = "ami-0abc123def456789"  # From Packer output
}
```

## Comparison: With vs. Without Golden AMI

### Without Golden AMI (Traditional Approach)
```
Launch Instance → Install OS Updates → Install Java → Install Jenkins 
→ Configure Jenkins → Install Plugins → Apply Security Settings
→ Configure Monitoring → Test → Ready

Time: 45-60 minutes
Risk: Configuration drift, inconsistent setups
```

### With Golden AMI (Packer Approach)
```
Launch Instance from Golden AMI → Mount EFS → Start Services → Ready

Time: 2-5 minutes
Risk: Minimal, all instances identical
```

## Conclusion

The Golden AMI approach using HashiCorp Packer is a best practice for:
- **Auto Scaling Groups**: Fast instance launches
- **Consistency**: Identical instances every time
- **Security**: Pre-hardened, compliant images
- **Efficiency**: Reduced launch time and costs

In our Jenkins HA project, the Golden AMI ensures that:
1. All Jenkins instances are identical
2. New instances launch quickly when scaling
3. Security and compliance requirements are met
4. Maintenance and updates are centralized

This approach transforms infrastructure from "cattle" (disposable, automated) rather than "pets" (manually configured, unique), which is essential for modern cloud-native applications.

