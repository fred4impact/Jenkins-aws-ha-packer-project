# Step-by-Step Guide: Jenkins AWS HA Packer Project

This document provides a comprehensive, step-by-step guide to build and deploy a High Availability Jenkins infrastructure on AWS using Packer, Ansible, Terraform, and other DevOps tools.

---

## Table of Contents

1. [Prerequisites and Initial Setup](#prerequisites-and-initial-setup)
2. [Step 1: AWS Account Configuration](#step-1-aws-account-configuration)
3. [Step 2: Local Environment Setup](#step-2-local-environment-setup)
4. [Step 3: Build Jenkins Golden AMI with Packer](#step-3-build-jenkins-golden-ami-with-packer)
5. [Step 4: Security Scan with Trivy (Optional but Recommended)](#step-4-security-scan-with-trivy-optional-but-recommended)
6. [Step 5: Configure Terraform Variables](#step-5-configure-terraform-variables)
7. [Step 6: Deploy Infrastructure with Terraform](#step-6-deploy-infrastructure-with-terraform)
8. [Step 7: Access and Verify Jenkins](#step-7-access-and-verify-jenkins)
9. [Step 8: Post-Deployment Configuration](#step-8-post-deployment-configuration)
10. [Step 9: Cleanup (When Needed)](#step-9-cleanup-when-needed)

---

## Prerequisites and Initial Setup

### Required Tools

Before starting, ensure you have the following tools installed:

- **AWS CLI** (v2) - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Terraform** (>= 1.0) - [Installation Guide](https://developer.hashicorp.com/terraform/downloads)
- **Packer** (>= 1.8) - [Installation Guide](https://developer.hashicorp.com/packer/downloads)
- **Ansible** (>= 2.9) - [Installation Guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- **Docker** (for Trivy scanning) - [Installation Guide](https://docs.docker.com/get-docker/)
- **Git** - For cloning repositories
- **SSH Key Pair** - For EC2 access

### Verify Installations

```bash
# Check AWS CLI
aws --version

# Check Terraform
terraform version

# Check Packer
packer version

# Check Ansible
ansible --version

# Check Docker
docker --version
```

---

## Step 1: AWS Account Configuration

### 1.1 Configure AWS Credentials

```bash
# Configure AWS CLI with your credentials
aws configure

# You'll be prompted for:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

### 1.2 Create EC2 Key Pair

```bash
# Create a new key pair in AWS
aws ec2 create-key-pair \
    --key-name jenkins-ha-keypair \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/jenkins-ha-keypair.pem

# Set proper permissions
chmod 400 ~/.ssh/jenkins-ha-keypair.pem

# Note the key pair name - you'll need it for Terraform
```

### 1.3 Verify AWS Permissions

Ensure your AWS user/role has permissions for:
- EC2 (create instances, AMIs, snapshots)
- VPC (create VPC, subnets, gateways)
- IAM (create roles and policies)
- EFS (create file systems)
- ELB (create load balancers)
- S3 (create buckets)
- CloudWatch (create logs and metrics)

### 1.4 (Optional) Create S3 Bucket for Terraform State

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://demo-terra-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket demo-terra-state-bucket \
    --versioning-configuration Status=Enabled
```

---

## Step 2: Local Environment Setup

### 2.1 Navigate to Project Directory

```bash
cd /Users/mac/Documents/DEVOPS-PORTFOLIOS/jenkins-aws-ha-packer
```

### 2.2 Review Project Structure

```bash
# View project structure
tree -L 2
# or
ls -la
```

Key directories:
- `packer/` - Packer configuration for AMI building
- `terraform/` - Terraform infrastructure code
- `playbooks/` - Ansible playbooks for configuration
- `jenkins-config/` - Jenkins configuration files

### 2.3 Set Environment Variables (Optional)

```bash
# Set AWS region
export AWS_REGION=us-east-1

# Set Jenkins version
export JENKINS_VERSION=2.414.3

# Set Java version
export JAVA_VERSION=17
```

---

## Step 3: Build Jenkins Golden AMI with Packer

### 3.1 Navigate to Packer Directory

```bash
# IMPORTANT: You MUST run Packer from the packer directory within the project
# The paths in jenkins-ami.pkr.hcl are relative to this directory
cd /Users/mac/Documents/DEVOPS-PORTFOLIOS/jenkins-aws-ha-packer/packer

# Verify you're in the correct directory
pwd
# Should show: .../jenkins-aws-ha-packer/packer

# Verify the relative paths exist
ls ../jenkins-config/
ls ../playbooks/
```

**⚠️ Critical:** The Packer configuration uses relative paths (`../jenkins-config/` and `../playbooks/`). These paths assume you're running Packer from the `packer` directory. If you run from a different location, the paths won't work.

### 3.2 Review Packer Configuration

```bash
# View Packer configuration
cat jenkins-ami.pkr.hcl

# View variables
cat variables.pkr.hcl

# View installation script
cat scripts/install-jenkins.sh
```

### 3.3 Initialize Packer

```bash
# Initialize Packer plugins
packer init .
```

Expected output:
```
Installed plugin github.com/hashicorp/amazon v1.x.x
Installed plugin github.com/hashicorp/ansible v1.x.x
```

**Note:** The Ansible provisioner plugin will be installed automatically. However, you also need Ansible installed on your local machine for the provisioner to work. If you don't have Ansible installed:

```bash
# On macOS
brew install ansible

# On Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y ansible

# On Linux (RHEL/CentOS)
sudo yum install -y ansible

# Verify installation
ansible --version
```

### 3.4 Validate Packer Configuration

```bash
# Validate the Packer configuration
# Note: Validate the directory (.) to load all .pkr.hcl files including variables
packer validate .

# OR validate the specific file with variables provided
packer validate -var 'aws_region=us-east-1' jenkins-ami.pkr.hcl
```

Expected output:
```
The configuration is valid.
```

**Note:** When validating, Packer needs to load all `.pkr.hcl` files in the directory. Validating the directory (`.`) ensures variables from `variables.pkr.hcl` are loaded. Alternatively, you can provide variables explicitly with `-var` flags.

### 3.5 Format Packer Configuration (Optional)

```bash
# Format the configuration file
packer fmt jenkins-ami.pkr.hcl
```

### 3.6 Fix Permission Issues (macOS - If Needed)

If you're getting permission denied errors on macOS, fix the Packer directories:

```bash
# Find where Packer stores plugins and data
PACKER_PLUGIN_DIR="$HOME/.packer.d/plugins"
PACKER_CACHE_DIR="$HOME/.packer.d"

# Create directories if they don't exist
mkdir -p "$PACKER_PLUGIN_DIR"
mkdir -p "$PACKER_CACHE_DIR"

# Fix permissions (make sure you own these directories)
sudo chown -R $(whoami) "$HOME/.packer.d"
chmod -R 755 "$HOME/.packer.d"

# Also fix temp directory permissions (if needed)
sudo chown -R $(whoami) /var/folders
# OR create a custom temp directory
export TMPDIR="$HOME/tmp"
mkdir -p "$TMPDIR"
chmod 755 "$TMPDIR"

# Verify Packer can write
packer version
```

**Alternative: Use a custom working directory (Maintain Directory Structure)**

If you need to work from a different location, you must maintain the project structure:

```bash
# Create a working directory
mkdir -p ~/packer-work
cd ~/packer-work

# Copy the ENTIRE project structure (not just packer files)
cp -r /Users/mac/Documents/DEVOPS-PORTFOLIOS/jenkins-aws-ha-packer/* .

# Now navigate to packer directory
cd packer

# Set environment variable for temp files
export TMPDIR="$HOME/tmp"
mkdir -p "$TMPDIR"

# Now run packer from the packer directory
packer init .
packer validate .
```

**Note:** The relative paths (`../jenkins-config/` and `../playbooks/`) require the full project structure. Simply copying the `packer` directory alone won't work.

### 3.7 Build the AMI

```bash
# Build the AMI - validate the directory (.) to load all .pkr.hcl files
# This ensures variables from variables.pkr.hcl are loaded
packer build .

# OR build with custom variables explicitly provided
packer build \
    -var 'aws_region=us-east-1' \
    -var 'jenkins_version=2.414.3' \
    -var 'java_version=17' \
    .
```

**⚠️ Important Notes:**
- **Don't use `sudo`** with Packer - it can cause permission issues with log files and plugin directories
- **Build the directory (`.`)** instead of a single file to ensure all `.pkr.hcl` files (including `variables.pkr.hcl`) are loaded
- If you must build a single file, provide all variables explicitly with `-var` flags
- If you still get permission errors, fix the directories as shown in Step 3.6 above

**What happens during build:**
1. Packer launches a temporary EC2 instance
2. Runs `install-jenkins.sh` script to install base software
3. Executes Ansible playbook for configuration
4. Creates AMI snapshot
5. Terminates temporary instance

**Expected output:**
```
==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs.jenkins: AMIs were created:
us-east-1: ami-0abc123def456789
```

### 3.8 Save AMI ID

```bash
# Extract and save AMI ID from build output
# Note: Use . (directory) instead of specific file to load all variables
AMI_ID=$(packer build -machine-readable . | \
    grep 'artifact,0,id' | cut -d, -f6 | cut -d: -f2)

echo "AMI ID: $AMI_ID"

# Save to file for later use
echo $AMI_ID > ../ami-id.txt

# OR manually copy the AMI ID from the build output
# Look for a line like: "us-east-1: ami-0abc123def456789"
```

**⚠️ Important:** Copy the AMI ID - you'll need it for Terraform configuration.

---

## Step 4: Security Scan with Trivy (Optional but Recommended)

### 4.1 Pull Trivy Docker Image

```bash
# Pull latest Trivy image
docker pull aquasec/trivy:latest
```

### 4.2 Scan the AMI

```bash
# Read AMI ID from previous step
AMI_ID=$(cat ../ami-id.txt)

# Scan AMI for vulnerabilities
docker run --rm \
    -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    -e AWS_DEFAULT_REGION=us-east-1 \
    aquasec/trivy image \
    --format json \
    --output trivy-report.json \
    --severity HIGH,CRITICAL \
    $AMI_ID

# Generate HTML report
docker run --rm \
    -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    -e AWS_DEFAULT_REGION=us-east-1 \
    aquasec/trivy image \
    --format template \
    --template '@contrib/html.tpl' \
    --output trivy-report.html \
    --severity HIGH,CRITICAL \
    $AMI_ID
```

### 4.3 Review Scan Results

```bash
# View JSON report
cat trivy-report.json | jq .

# Open HTML report (if on local machine)
open trivy-report.html
```

**⚠️ Important:** If critical vulnerabilities are found, consider:
- Updating packages in the AMI
- Rebuilding the AMI with security patches
- Documenting acceptable risks

---

## Step 5: Configure Terraform Variables

### 5.1 Navigate to Terraform Directory

```bash
cd ../terraform/main
```

### 5.2 Copy Example Variables File

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars
```

### 5.3 Edit terraform.tfvars

```bash
# Open in your preferred editor
vi terraform.tfvars
# or
nano terraform.tfvars
# or
code terraform.tfvars
```

### 5.4 Configure Required Variables

Update `terraform.tfvars` with your values:

```hcl
# Basic Configuration
project_name = "ha-jenkins"
environment  = "prod"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Jenkins AMI ID (from Step 3)
jenkins_ami_id = "ami-0abc123def456789"  # Replace with your AMI ID

# Instance Configuration
instance_type = "t3.medium"
key_name      = "jenkins-ha-keypair"  # Your key pair name from Step 1.2

# Auto Scaling Configuration
asg_min_size         = 2
asg_max_size         = 5
asg_desired_capacity = 2

# Volume Configuration
volume_size = 30

# Security Configuration
allowed_ssh_cidrs = ["10.0.0.0/16"]  # Restrict to your VPN or bastion

# Jenkins Admin Credentials
jenkins_admin_user = "admin"
jenkins_admin_pass = "YourSecurePassword123!"  # Change this!

# EFS Configuration
enable_efs_backup = true

# S3 Artifact Retention
artifact_retention_days = 90

# Additional Tags
tags = {
  Team        = "DevOps"
  Application = "Jenkins"
}
```

**⚠️ Security Note:** 
- Use a strong password for `jenkins_admin_pass`
- Consider using AWS Secrets Manager for production
- Never commit `terraform.tfvars` to Git (it's in .gitignore)

### 5.5 (Optional) Configure Terraform Backend

If using S3 backend for state:

```bash
# Create backend.tf file
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "ha-jenkins/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}
EOF
```

---

## Step 6: Deploy Infrastructure with Terraform

### 6.1 Initialize Terraform

```bash
# Initialize Terraform (downloads providers and modules)
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

### 6.2 Format Terraform Files

```bash
# Format all Terraform files
terraform fmt -recursive
```

### 6.3 Validate Terraform Configuration

```bash
# Validate the configuration
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

### 6.4 Review Execution Plan

```bash
# Create execution plan
terraform plan -out=tfplan

# Review the plan
terraform show tfplan
```

**Review the plan carefully:**
- Check resources being created
- Verify AMI ID is correct
- Confirm region and availability zones
- Review security group rules

### 6.5 Apply Terraform Configuration

```bash
# Apply the configuration
terraform apply tfplan

# OR apply directly (will prompt for confirmation)
terraform apply
```

**What gets created:**
1. VPC with public and private subnets
2. Internet Gateway and NAT Gateways
3. Security Groups
4. EFS file system
5. Application Load Balancer
6. Auto Scaling Group
7. Launch Template
8. S3 bucket for artifacts
9. IAM roles and policies
10. CloudWatch alarms

**Expected output:**
```
Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

Outputs:

jenkins_url = "http://ha-jenkins-alb-123456789.us-east-1.elb.amazonaws.com"
alb_dns_name = "ha-jenkins-alb-123456789.us-east-1.elb.amazonaws.com"
efs_id = "fs-0abc123def456789"
```

### 6.6 Save Outputs

```bash
# Save outputs to file
terraform output -json > outputs.json

# View outputs
terraform output
```

---

## Step 7: Access and Verify Jenkins

### 7.1 Get Jenkins URL

```bash
# Get Jenkins URL from Terraform output
terraform output jenkins_url

# Or from saved outputs
cat outputs.json | jq -r '.jenkins_url.value'
```

### 7.2 Wait for Instances to Be Ready

```bash
# Check Auto Scaling Group status
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names ha-jenkins-asg \
    --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
    --output table

# Wait for instances to be healthy (may take 5-10 minutes)
# Check ALB target health
aws elbv2 describe-target-health \
    --target-group-arn $(terraform output -raw target_group_arn) \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table
```

### 7.3 Access Jenkins Web UI

1. Open browser and navigate to the Jenkins URL from Step 7.1
2. You should see the Jenkins login page
3. Login with credentials from `terraform.tfvars`:
   - Username: `admin` (or your configured username)
   - Password: Your configured password

### 7.4 Verify Jenkins Configuration

```bash
# SSH to one of the instances (if key pair is configured)
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names ha-jenkins-asg \
    --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
    --output text)

INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

# Check Jenkins service status
ssh -i ~/.ssh/jenkins-ha-keypair.pem ubuntu@$INSTANCE_IP \
    "sudo systemctl status jenkins"

# Check EFS mount
ssh -i ~/.ssh/jenkins-ha-keypair.pem ubuntu@$INSTANCE_IP \
    "df -h | grep efs"
```

### 7.5 Verify High Availability

```bash
# Check that multiple instances are running
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names ha-jenkins-asg \
    --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
    --output table

# Verify instances are in different AZs
aws ec2 describe-instances \
    --instance-ids $(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names ha-jenkins-asg \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output text) \
    --query 'Reservations[*].Instances[*].[InstanceId,AvailabilityZone]' \
    --output table
```

---

## Step 8: Post-Deployment Configuration

### 8.1 Configure Jenkins Plugins

1. Log in to Jenkins
2. Go to **Manage Jenkins** → **Manage Plugins**
3. Install recommended plugins or specific ones:
   - Pipeline
   - Docker Pipeline
   - AWS Steps
   - GitHub Integration
   - etc.

### 8.2 Configure Jenkins Credentials

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Add AWS credentials for Jenkins to use
3. Add GitHub/GitLab credentials if needed
4. Add Docker Hub credentials if needed

### 8.3 Configure Jenkins System Settings

1. Go to **Manage Jenkins** → **Configure System**
2. Configure:
   - Jenkins URL (should match ALB DNS name)
   - Number of executors
   - Cloud settings (if using Jenkins agents)
   - Email notifications

### 8.4 Test Jenkins Pipeline (Optional)

Create a test pipeline to verify everything works:

1. Go to **New Item** → **Pipeline**
2. Create a simple pipeline:

```groovy
pipeline {
    agent any
    stages {
        stage('Hello') {
            steps {
                echo 'Hello from Jenkins HA!'
            }
        }
    }
}
```

3. Run the pipeline and verify it executes successfully

### 8.5 Set Up Monitoring

```bash
# Check CloudWatch logs
aws logs describe-log-groups \
    --log-group-name-prefix /aws/ec2/jenkins \
    --query 'logGroups[*].logGroupName' \
    --output table

# Set up CloudWatch alarms (if not already created by Terraform)
# Monitor:
# - CPU utilization
# - Memory usage
# - ALB target health
# - EFS storage
```

---

## Step 9: Cleanup (When Needed)

### 9.1 Destroy Infrastructure

**⚠️ Warning:** This will delete all resources including EFS data. Ensure you have backups!

```bash
# Navigate to Terraform directory
cd terraform/main

# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy

# Confirm destruction when prompted
```

### 9.2 Deregister AMI (Optional)

```bash
# Get AMI ID
AMI_ID=$(cat ../../ami-id.txt)

# Get snapshot ID
SNAPSHOT_ID=$(aws ec2 describe-images \
    --image-ids $AMI_ID \
    --query 'Images[0].BlockDeviceMappings[0].Ebs.SnapshotId' \
    --output text)

# Deregister AMI
aws ec2 deregister-image --image-id $AMI_ID

# Delete snapshot
aws ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID
```

### 9.3 Clean Up Local Files

```bash
# Remove local files
rm -f ami-id.txt
rm -f terraform.tfvars
rm -f outputs.json
rm -f trivy-report.*
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Packer Build Fails

**Symptoms:** Packer build fails with authentication or permission errors

**Solutions:**
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM permissions
aws iam get-user

# Verify region is correct
aws ec2 describe-regions --region-names us-east-1
```

#### Issue 2: Terraform Apply Fails

**Symptoms:** Terraform fails to create resources

**Solutions:**
```bash
# Check Terraform state
terraform state list

# Verify variables
terraform console
> var.jenkins_ami_id

# Check AWS service quotas
aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-0263D0A3  # Running On-Demand EC2 instances
```

#### Issue 3: Jenkins Not Accessible

**Symptoms:** Cannot access Jenkins via ALB URL

**Solutions:**
```bash
# Check ALB target health
aws elbv2 describe-target-health \
    --target-group-arn <target-group-arn>

# Check security groups
aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=ha-jenkins-*"

# Check instance logs
aws logs tail /aws/ec2/jenkins --follow
```

#### Issue 4: EFS Mount Fails

**Symptoms:** Jenkins instances cannot mount EFS

**Solutions:**
```bash
# Verify EFS mount targets
aws efs describe-mount-targets \
    --file-system-id <efs-id>

# Check security group rules
# EFS security group must allow NFS traffic from Jenkins security group

# Test mount manually
sudo mount -t efs -o tls,iam <efs-id>:/ /mnt/efs
```

---

## Next Steps

After successful deployment:

1. **Set up CI/CD pipelines** in Jenkins
2. **Configure backup strategy** for Jenkins data
3. **Set up monitoring and alerting** in CloudWatch
4. **Implement disaster recovery** procedures
5. **Document runbooks** for operations team
6. **Set up automated AMI updates** via Jenkins pipeline
7. **Configure SSL/TLS** certificates for HTTPS
8. **Implement blue-green deployments** for AMI updates

---

## Additional Resources

- [Packer Documentation](https://developer.hashicorp.com/packer/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [AWS EFS Documentation](https://docs.aws.amazon.com/efs/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)

---

## Support

For issues or questions:
- Review project README files
- Check AWS service documentation
- Review Terraform and Packer logs
- Consult team documentation

---

**Last Updated:** $(date)
**Project Version:** 1.0.0


### my directory 
/Users/mac/packer-work