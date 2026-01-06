# High Availability Jenkins on AWS

This project provisions a highly available Github-Actions/Jenkins CI/CD platform on AWS using Terraform for infrastructure as code and HashiCorp Packer for building organization-specific Jenkins AMIs.

## Architecture Overview

The solution implements a production-grade, highly available Jenkins setup with:

- **Multi-AZ Deployment**: Jenkins instances deployed across multiple Availability Zones
- **Auto Scaling**: Automatic scaling based on CPU utilization
- **Shared Storage**: EFS for shared Jenkins home directory and workspace
- **Load Balancing**: Application Load Balancer for traffic distribution
- **High Availability**: Zero-downtime deployments and automatic failover

### Infrastructure Components

1. **VPC**: Custom VPC with public and private subnets across 2 Availability Zones
2. **Internet Gateway**: For public internet access
3. **NAT Gateways**: For outbound internet access from private subnets
4. **Application Load Balancer**: Distributes traffic to Jenkins instances
5. **Auto Scaling Group**: Manages Jenkins EC2 instances
6. **EFS**: Shared file system for Jenkins home directory
7. **S3 Bucket**: For Jenkins artifacts storage
8. **Security Groups**: Network-level security controls
9. **IAM Roles**: For secure access to AWS services

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Packer >= 1.8
- An AWS account with appropriate permissions
- SSH key pair in AWS (for EC2 access)

## Project Structure

```
ha-jenkins-aws/
├── packer/
│   ├── jenkins-ami.pkr.hcl          # Packer configuration for AMI
│   ├── variables.pkr.hcl            # Packer variables
│   └── scripts/
│       └── install-jenkins.sh        # Jenkins installation script
├── terraform/
│   ├── main/
│   │   ├── main.tf                  # Main Terraform configuration
│   │   ├── variables.tf              # Variable definitions
│   │   ├── outputs.tf                # Output values
│   │   ├── locals.tf                 # Local values
│   │   └── terraform.tfvars.example # Example variables file
│   └── modules/
│       ├── vpc/                      # VPC module
│       ├── efs/                      # EFS module
│       ├── elb/                      # Load Balancer module
│       └── asg/                      # Auto Scaling Group module
├── jenkins-config/
│   ├── jenkins-ha-config.xml         # Jenkins HA configuration
│   └── init.groovy                   # Jenkins initialization script
└── README.md                          # This file
```

## GitLab CI/CD Pipeline

This project includes a complete GitLab CI/CD pipeline that automates the entire deployment process:

1. **Stage I: Checkout** - Clones repository and creates `jenkinsrole.tar`
2. **Stage II: Terraform** - Initializes, validates, plans, and applies Terraform (creates EFS, builds AMI with Packer, deploys infrastructure)
3. **Stage III: Trivy Scan** - Scans the built AMI for security vulnerabilities
4. **Stage IV: Notify** - Sends pipeline summary

### Quick Start with GitLab CI/CD

1. **Configure GitLab CI/CD Variables** (Settings → CI/CD → Variables):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_DEFAULT_REGION`
   - `TF_STATE_BUCKET`
   - Other optional variables (see `GITLAB-CICD-SETUP.md`)

2. **Push code to GitLab**:
   ```bash
   git remote add origin https://gitlab.com/your-username/jenkins-aws-ha-packer-project.git
   git push -u origin main
   ```

3. **Run the pipeline**:
   - Pipeline runs automatically on push
   - `terraform_apply` requires manual approval for safety
   - Download artifacts (AMI ID, security reports) after completion

For detailed setup instructions, see **[GITLAB-CICD-SETUP.md](GITLAB-CICD-SETUP.md)**.

---

## Step-by-Step Deployment (Manual)

### Step 1: Build Jenkins AMI with Packer

1. Navigate to the packer directory:
   ```bash
   cd ha-jenkins-aws/packer
   ```

2. Initialize Packer:
   ```bash
   packer init .
   ```

3. Validate the Packer configuration:
   ```bash
   packer validate jenkins-ami.pkr.hcl
   ```

4. Build the AMI:
   ```bash
   packer build \
     -var 'aws_region=us-east-1' \
     -var 'jenkins_version=2.414.3' \
     jenkins-ami.pkr.hcl
   ```

5. Note the AMI ID from the build output. You'll need this for Terraform.

### Step 2: Configure Terraform Variables

1. Navigate to the Terraform directory:
   ```bash
   cd ../terraform/main
   ```

2. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` with your values:
   - Set `jenkins_ami_id` to the AMI ID from Packer
   - Configure `key_name` with your AWS key pair name
   - Set `jenkins_admin_user` and `jenkins_admin_pass`
   - Adjust other variables as needed

### Step 3: Configure Terraform Backend (Optional)

Create a `backend.tf` file or configure S3 backend via CLI:

```bash
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=ha-jenkins/terraform.tfstate" \
  -backend-config="region=us-east-1"
```

### Step 4: Deploy Infrastructure with Terraform

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the execution plan:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. Note the outputs, especially the `jenkins_url` and `alb_dns_name`.

### Step 5: Access Jenkins

1. Get the Jenkins URL from Terraform outputs:
   ```bash
   terraform output jenkins_url
   ```

2. Access Jenkins in your browser:
   - URL: `http://<alb-dns-name>`
   - Initial admin user: As configured in `terraform.tfvars`
   - Initial admin password: As configured in `terraform.tfvars`

3. Complete the Jenkins setup wizard (if first instance).

## Configuration Details

### Jenkins HA Configuration

- **Shared Home Directory**: Jenkins home is stored on EFS, accessible by all instances
- **Session Affinity**: ALB uses cookie-based stickiness for session persistence
- **Auto Scaling**: Scales based on CPU utilization (scale up at 70%, scale down at 30%)
- **Health Checks**: ALB health checks ensure only healthy instances receive traffic

### Security

- Jenkins instances are in private subnets
- Security groups restrict access to necessary ports only
- IAM roles with least privilege for AWS service access
- EFS encryption at rest
- S3 bucket encryption enabled

### Monitoring

- CloudWatch metrics for EC2 instances
- CloudWatch Logs for Jenkins logs
- Auto Scaling metrics and alarms
- ALB access logs

## Customization

### Organization-Specific AMI

The Packer configuration allows you to customize the Jenkins AMI with:

- Organization-specific plugins
- Custom Jenkins configuration
- Pre-installed tools (Docker, kubectl, Terraform, etc.)
- Security hardening
- Custom scripts and utilities

Edit `packer/scripts/install-jenkins.sh` to add your organization-specific requirements.

### Scaling Configuration

Adjust auto-scaling parameters in `terraform.tfvars`:

```hcl
asg_min_size         = 2
asg_max_size         = 5
asg_desired_capacity = 2
```

### Instance Type

Change the instance type in `terraform.tfvars`:

```hcl
instance_type = "t3.large"  # or t3.xlarge for higher performance
```

## Maintenance

### Updating Jenkins AMI

1. Make changes to Packer configuration
2. Rebuild AMI with Packer
3. Update `jenkins_ami_id` in `terraform.tfvars`
4. Run `terraform apply` to update the launch template

### Updating Infrastructure

1. Modify Terraform files as needed
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes

## Troubleshooting

### Jenkins Not Accessible

1. Check ALB health checks: Ensure instances are healthy
2. Verify security groups: Allow traffic from ALB to instances
3. Check instance logs: SSH to instance and check `/var/log/jenkins/jenkins.log`

### EFS Mount Issues

1. Verify EFS security group allows traffic from Jenkins security group
2. Check IAM role has EFS permissions
3. Verify EFS mount targets are in correct subnets

### Auto Scaling Not Working

1. Check CloudWatch alarms are created
2. Verify IAM permissions for Auto Scaling
3. Review ASG activity history in AWS Console

## Cost Optimization

- Use Spot Instances for non-production environments
- Enable EFS lifecycle management for cost savings
- Configure S3 lifecycle policies for artifact retention
- Use appropriate instance types for your workload

## Cleanup

To destroy all resources:

```bash
cd terraform/main
terraform destroy
```

**Note**: This will delete all resources including EFS data. Ensure you have backups before destroying.

## Support

For issues or questions:
- Review Terraform and Packer documentation
- Check AWS service documentation
- Review Jenkins HA documentation

## License

This project is provided as-is for educational and organizational use.

