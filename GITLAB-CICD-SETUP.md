# GitLab CI/CD Pipeline Setup Guide

This guide explains how to set up and use the GitLab CI/CD pipeline for the Jenkins HA infrastructure deployment with integrated Terraform-Packer flow.

---

## 📋 Pipeline Overview

The pipeline follows a three-stage process:

```
┌─────────────────────────────────────────────────────────────┐
│                    GITLAB CI/CD PIPELINE                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STAGE I: CHECKOUT                    │
        │  - Clone repository                   │
        │  - Create jenkinsrole.tar             │
        │  - Prepare artifacts                  │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STAGE II: TERRAFORM                  │
        │  1. Terraform Init                    │
        │  2. Terraform Validate                │
        │  3. Terraform Plan                    │
        │  4. Terraform Apply (Manual)          │
        │     ├─ Creates EFS                    │
        │     ├─ Calls Packer with EFS ID      │
        │     ├─ Packer builds AMI             │
        │     └─ Deploys infrastructure        │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STAGE III: TRIVY SCAN                │
        │  - Scan built AMI                   │
        │  - Generate security reports         │
        └───────────────────────────────────────┘
                            │
                            ▼
                    ✅ Pipeline Complete
```

---

## 🔧 Prerequisites

Before setting up the pipeline, ensure you have:

- ✅ **GitLab Account** with a project repository
- ✅ **AWS Account** with appropriate IAM permissions
- ✅ **GitLab Runner** (shared or self-hosted) with Docker executor
- ✅ **S3 Bucket** for Terraform state (already configured in `terraform/main/main.tf`)
- ✅ **Access to GitLab project** (Maintainer or Owner role)

### Required AWS Permissions

Your AWS credentials need permissions for:
- **EC2**: Create instances, AMIs, snapshots, launch templates, ASG
- **VPC**: Create VPCs, subnets, security groups, internet gateways, NAT gateways
- **EFS**: Create file systems, mount targets, access points
- **ELB**: Create application load balancers, target groups, listeners
- **IAM**: Create roles, instance profiles, policies
- **S3**: Read/write for Terraform state and artifacts
- **CloudWatch**: Create log groups, metrics, alarms

### Required Tools on GitLab Runner

The pipeline uses Docker images that include:
- Terraform (hashicorp/terraform)
- Packer (installed in pipeline)
- Ansible (installed in pipeline)
- AWS CLI (installed in pipeline)
- Trivy (aquasec/trivy)

---

## 📝 Step 1: Configure GitLab CI/CD Variables

### 1.1 Access GitLab CI/CD Variables

1. Go to your GitLab project
2. Navigate to **Settings** → **CI/CD**
3. Expand **Variables** section
4. Click **Add variable**

### 1.2 Required Variables

Add the following variables (mark sensitive ones as **Protected** and **Masked**):

| Variable Name | Value | Protected | Masked | Description |
|--------------|-------|-----------|--------|-------------|
| `AWS_ACCESS_KEY_ID` | `your-access-key` | ✅ | ✅ | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | `your-secret-key` | ✅ | ✅ | AWS Secret Key |
| `AWS_DEFAULT_REGION` | `us-east-1` | ❌ | ❌ | AWS Region |
| `TF_STATE_BUCKET` | `your-terraform-state-bucket` | ❌ | ❌ | S3 bucket for Terraform state |
| `TF_STATE_KEY` | `ha-jenkins/terraform.tfstate` | ❌ | ❌ | S3 key for Terraform state (optional) |
| `TF_STATE_REGION` | `us-east-1` | ❌ | ❌ | Region for Terraform state bucket (optional) |
| `TF_VARS_FILE` | `dev.tfvars` | ❌ | ❌ | Terraform variables file to use (optional) |

### 1.3 Optional Variables

| Variable Name | Value | Description |
|--------------|-------|-------------|
| `JENKINS_VERSION` | `2.414.3` | Jenkins version to install |
| `JAVA_VERSION` | `17` | Java version |
| `PACKER_VERSION` | `1.10.0` | Packer version to use |
| `TERRAFORM_VERSION` | `1.6.0` | Terraform version to use |
| `TRIVY_EXIT_CODE` | `0` | Exit code for Trivy (0 = don't fail on vulnerabilities) |
| `TRIVY_SEVERITY` | `HIGH,CRITICAL` | Severity levels to check |

### 1.4 Variable Configuration

For each variable:
1. **Variable Key**: Enter the variable name
2. **Value**: Enter the variable value
3. **Type**: Select **Variable** (default)
4. **Environment scope**: Leave as `*` (all environments)
5. **Flags**:
   - ✅ **Protect variable**: Check for sensitive data (AWS keys, passwords)
   - ✅ **Mask variable**: Check to hide in logs
   - ❌ **Expand variable reference**: Leave unchecked

---

## 📁 Step 2: Prepare Terraform Variables File

### 2.1 Create terraform.tfvars

Copy the example file and customize:

```bash
cd terraform/main
cp dev.tfvars terraform.tfvars
```

### 2.2 Update terraform.tfvars

Edit `terraform/main/terraform.tfvars` with your values:

```hcl
project_name = "your-project-name"
environment  = "dev"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Build AMI with Packer
build_ami_with_packer = true
jenkins_ami_id        = ""  # Leave empty when building with Packer

# Instance Configuration
instance_type = "t3.medium"
key_name      = "your-key-pair-name"

# Auto Scaling Configuration
asg_min_size         = 2
asg_max_size         = 3
asg_desired_capacity = 2

# Jenkins Admin Credentials
jenkins_admin_user = "admin"
jenkins_admin_pass = "your-secure-password"

# Security Configuration
allowed_ssh_cidrs = ["10.0.0.0/16"]

# EFS Configuration
enable_efs_backup = true

# S3 Artifact Retention
artifact_retention_days = 90
```

**⚠️ Important**: Do NOT commit `terraform.tfvars` with sensitive data. Use GitLab CI/CD variables instead, or add it to `.gitignore`.

---

## 🚀 Step 3: Push Code to GitLab

### 3.1 Initialize Git Repository (if not already done)

```bash
cd /Users/mac/Documents/DEVOPS-PORTFOLIOS/Jenkins-aws-ha-packer-project

# Initialize git if not already done
git init

# Add GitLab remote
git remote add origin https://gitlab.com/your-username/jenkins-aws-ha-packer-project.git

# Add all files
git add .

# Commit
git commit -m "Add GitLab CI/CD pipeline for Jenkins HA infrastructure"

# Push to GitLab
git push -u origin main
```

### 3.2 Verify Repository Structure

Ensure your repository has this structure:

```
jenkins-aws-ha-packer-project/
├── .gitlab-ci.yml          # GitLab CI/CD configuration
├── packer/
│   ├── jenkins-ami.pkr.hcl
│   ├── variables.pkr.hcl
│   └── scripts/
├── playbooks/
│   ├── jenkins-setup.yml
│   └── roles/
├── terraform/
│   ├── main/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── packer-build.tf
│   │   └── dev.tfvars
│   └── modules/
└── jenkins-config/
```

---

## 🔄 Step 4: Run the Pipeline

### 4.1 Automatic Trigger

The pipeline automatically runs on:
- Push to `main` or `develop` branches
- Merge requests

### 4.2 Manual Trigger

1. Go to **CI/CD** → **Pipelines**
2. Click **Run pipeline**
3. Select branch: `main` or `develop`
4. Click **Run pipeline**

### 4.3 Manual Approval for Terraform Apply

The `terraform_apply` job requires **manual approval** for safety:

1. Go to **CI/CD** → **Pipelines**
2. Click on the running pipeline
3. Wait for `terraform_plan` to complete
4. Click the **play button** (▶️) on `terraform_apply` job
5. Confirm the deployment

---

## 📊 Step 5: Monitor Pipeline Execution

### 5.1 View Pipeline Status

1. Go to **CI/CD** → **Pipelines**
2. Click on the pipeline to view stages
3. Watch each job execute:
   - ✅ **checkout_and_prepare**: Should complete quickly
   - ✅ **terraform_init**: Initializes Terraform
   - ✅ **terraform_validate**: Validates configuration
   - ✅ **terraform_plan**: Creates execution plan
   - ⏳ **terraform_apply**: Requires manual approval, takes 15-30 minutes
   - ⏳ **scan_ami**: Takes 5-10 minutes (Trivy scan)

### 5.2 View Job Logs

Click on any job to see detailed logs:
- Real-time output
- Error messages
- Build progress
- AWS resource creation

### 5.3 Download Artifacts

After pipeline completes:
1. Go to **CI/CD** → **Pipelines**
2. Click on completed pipeline
3. Click **Browse** next to artifacts
4. Download:
   - `ami-id.txt` - Built AMI ID
   - `terraform-outputs.json` - Terraform outputs
   - `trivy-report.html` - Security scan report
   - `manifest.json` - Packer manifest

---

## 🔍 Step 6: Verify Deployment

### 6.1 Check AWS Resources

1. **EC2 Console**: Verify ASG instances are running
2. **EFS Console**: Verify EFS file system is created
3. **ELB Console**: Verify Application Load Balancer is active
4. **VPC Console**: Verify VPC, subnets, security groups

### 6.2 Access Jenkins

1. Get ALB DNS name from Terraform outputs:
   ```bash
   terraform output alb_dns_name
   ```
2. Access Jenkins: `http://<alb-dns-name>:8080`
3. Login with credentials from `terraform.tfvars`

### 6.3 Check Security Scan

1. Download `trivy-report.html` from artifacts
2. Review vulnerabilities
3. Address critical/high severity issues if needed

---

## 🛠️ Troubleshooting

### Issue 1: AWS Credentials Not Working

**Error**: `Unable to locate credentials`

**Solution**:
- Verify GitLab CI/CD variables are set correctly
- Check if variables are marked as "Protected" (only available on protected branches)
- Ensure AWS credentials have correct permissions
- Verify IAM user has necessary policies attached

### Issue 2: Terraform State Lock

**Error**: `Error acquiring the state lock`

**Solution**:
- Check if another pipeline is running
- Wait for previous pipeline to complete
- If stuck, manually unlock: `terraform force-unlock <lock-id>`

### Issue 3: Packer Build Fails

**Error**: `Error building AMI`

**Solution**:
- Check Packer logs in `terraform_apply` job output
- Verify AWS region is correct
- Check instance type availability in region
- Review security group and subnet configurations
- Ensure EFS ID is passed correctly

### Issue 4: Trivy Scan Fails

**Error**: `Failed to scan AMI`

**Solution**:
- Verify AMI ID is passed correctly between stages
- Check AWS credentials for Trivy
- Ensure AMI is in same region as configured
- Verify AMI exists: `aws ec2 describe-images --image-ids <ami-id>`

### Issue 5: Terraform Apply Fails

**Error**: `Error applying Terraform`

**Solution**:
- Review Terraform plan output first
- Check for resource conflicts
- Verify all required variables are set
- Check AWS service quotas/limits
- Review CloudWatch logs for detailed errors

---

## 🔐 Security Best Practices

### 1. Secrets Management

- ✅ Use GitLab CI/CD variables for sensitive data
- ✅ Mark sensitive variables as "Protected" and "Masked"
- ✅ Never commit secrets to repository
- ✅ Rotate AWS credentials regularly

### 2. State Management

- ✅ Use S3 backend with versioning enabled
- ✅ Enable S3 bucket encryption
- ✅ Use DynamoDB for state locking (optional but recommended)
- ✅ Restrict access to state bucket

### 3. Access Control

- ✅ Use IAM roles instead of access keys when possible
- ✅ Follow principle of least privilege
- ✅ Enable MFA for GitLab account
- ✅ Use protected branches for production

### 4. Pipeline Security

- ✅ Require manual approval for production deployments
- ✅ Enable security scanning (Trivy)
- ✅ Review security reports before deployment
- ✅ Use separate AWS accounts for dev/staging/prod

---

## 📈 Advanced Configuration

### 1. Multiple Environments

Create separate pipelines for different environments:

```yaml
terraform_apply_dev:
  extends: terraform_apply
  variables:
    TF_VARS_FILE: "dev.tfvars"
    TF_STATE_KEY: "ha-jenkins/dev/terraform.tfstate"

terraform_apply_prod:
  extends: terraform_apply
  variables:
    TF_VARS_FILE: "prod.tfvars"
    TF_STATE_KEY: "ha-jenkins/prod/terraform.tfstate"
  when: manual
  only:
    - main
```

### 2. Slack Notifications

Add notification job:

```yaml
notify_slack:
  stage: notify
  image: curlimages/curl:latest
  script:
    - |
      curl -X POST "${SLACK_WEBHOOK_URL}" \
        -H 'Content-Type: application/json' \
        -d "{
          \"text\": \"Pipeline ${CI_PIPELINE_STATUS}: ${CI_PIPELINE_URL}\"
        }"
  only:
    - main
```

### 3. Scheduled Pipelines

Set up scheduled pipelines for regular builds:

1. Go to **CI/CD** → **Schedules**
2. Click **New schedule**
3. Configure:
   - Description: "Weekly AMI rebuild"
   - Interval: Weekly
   - Target branch: `main`
   - Active: ✅

### 4. Parallel AMI Builds

Build AMIs for multiple regions in parallel:

```yaml
build_ami_us_east:
  extends: .build_ami_template
  variables:
    AWS_REGION: "us-east-1"

build_ami_us_west:
  extends: .build_ami_template
  variables:
    AWS_REGION: "us-west-2"
```

---

## 📚 Additional Resources

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Packer Documentation](https://developer.hashicorp.com/packer/docs)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [AWS Best Practices](https://aws.amazon.com/architecture/well-architected/)

---

## ✅ Checklist

After completing all steps, verify:

- [ ] GitLab repository is set up
- [ ] All CI/CD variables are configured
- [ ] `.gitlab-ci.yml` is committed and pushed
- [ ] GitLab Runner is available (shared or self-hosted)
- [ ] Terraform variables file is prepared
- [ ] S3 bucket for Terraform state exists
- [ ] Pipeline runs successfully
- [ ] EFS is created
- [ ] AMI is built and available in AWS
- [ ] Infrastructure is deployed
- [ ] Trivy scan completes and generates reports
- [ ] Jenkins is accessible via ALB
- [ ] Artifacts are downloadable

---

**Last Updated**: 2024
**Version**: 1.0.0








