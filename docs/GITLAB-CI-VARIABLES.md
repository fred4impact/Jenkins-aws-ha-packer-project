# GitLab CI/CD Variables Reference

This document lists all variables that need to be configured in GitLab CI/CD for the Jenkins HA infrastructure pipeline.

## 📍 How to Set Variables

1. Go to your GitLab project
2. Navigate to **Settings** → **CI/CD**
3. Expand **Variables** section
4. Click **Add variable**
5. Configure each variable as described below

---

## 🔴 Required Variables

These variables **must** be set for the pipeline to work:

| Variable Name | Type | Protected | Masked | Description | Example |
|--------------|------|-----------|--------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | Variable | ✅ Yes | ✅ Yes | AWS Access Key ID for authentication | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | Variable | ✅ Yes | ✅ Yes | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `TF_STATE_BUCKET` | Variable | ❌ No | ❌ No | S3 bucket name for storing Terraform state | `my-terraform-state-bucket` |

---

## 🟡 Optional Variables (with defaults)

These variables have default values but can be customized:

| Variable Name | Default Value | Description | When to Override |
|--------------|---------------|-------------|------------------|
| `AWS_DEFAULT_REGION` | `us-east-1` | AWS region for deployment | When deploying to different region |
| `AWS_REGION` | `us-east-1` | AWS region (used if `AWS_DEFAULT_REGION` not set) | When deploying to different region |
| `TF_STATE_KEY` | `ha-jenkins/terraform.tfstate` | S3 key/path for Terraform state file | For multi-environment deployments |
| `TF_STATE_REGION` | `us-east-1` | Region where Terraform state bucket is located | If state bucket is in different region |
| `TF_VARS_FILE` | `dev.tfvars` | Terraform variables file to use | For different environments (dev/staging/prod) |
| `JENKINS_VERSION` | `2.414.3` | Jenkins version to install in AMI | To use different Jenkins version |
| `JAVA_VERSION` | `17` | Java version for Jenkins | To use different Java version |
| `TERRAFORM_VERSION` | `1.6.0` | Terraform version (defined in pipeline) | To use different Terraform version |
| `PACKER_VERSION` | `1.10.0` | Packer version (defined in pipeline) | To use different Packer version |
| `TRIVY_SEVERITY` | `HIGH,CRITICAL` | Trivy scan severity levels | To scan for different severity levels |
| `TRIVY_EXIT_CODE` | `0` | Trivy exit code (0=don't fail, 1=fail on findings) | To fail pipeline on vulnerabilities |

---

## 📝 Variable Details

### AWS Credentials

**Required for all stages that interact with AWS**

- **`AWS_ACCESS_KEY_ID`**: Your AWS IAM user access key
- **`AWS_SECRET_ACCESS_KEY`**: Your AWS IAM user secret key

**Security Settings:**
- ✅ **Protected**: Yes (only available on protected branches)
- ✅ **Masked**: Yes (hidden in logs)

**IAM Permissions Required:**
- EC2 (instances, AMIs, snapshots, launch templates, ASG)
- VPC (VPCs, subnets, security groups, internet gateways, NAT gateways)
- EFS (file systems, mount targets, access points)
- ELB (application load balancers, target groups, listeners)
- IAM (roles, instance profiles, policies)
- S3 (read/write for Terraform state)
- CloudWatch (log groups, metrics, alarms)

### Terraform State Configuration

**Required for Terraform backend**

- **`TF_STATE_BUCKET`**: Name of your S3 bucket for Terraform state
  - Example: `my-company-terraform-state`
  - Must exist before running pipeline
  - Should have versioning enabled

- **`TF_STATE_KEY`** (optional): Path/key for state file in S3
  - Default: `ha-jenkins/terraform.tfstate`
  - Use different keys for different environments:
    - Dev: `ha-jenkins/dev/terraform.tfstate`
    - Prod: `ha-jenkins/prod/terraform.tfstate`

- **`TF_STATE_REGION`** (optional): Region where state bucket is located
  - Default: `us-east-1`
  - Set if bucket is in different region

### Terraform Variables File

- **`TF_VARS_FILE`** (optional): Which `.tfvars` file to use
  - Default: `dev.tfvars`
  - Should exist in `terraform/main/` directory
  - Examples: `dev.tfvars`, `staging.tfvars`, `prod.tfvars`

### Application Versions

- **`JENKINS_VERSION`** (optional): Jenkins version to install
  - Default: `2.414.3`
  - Check [Jenkins releases](https://www.jenkins.io/download/) for latest

- **`JAVA_VERSION`** (optional): Java version for Jenkins
  - Default: `17`
  - Supported: `11`, `17`, `21`

### Tool Versions

- **`TERRAFORM_VERSION`** (optional): Terraform version
  - Default: `1.6.0` (defined in pipeline variables)
  - Check [Terraform releases](https://github.com/hashicorp/terraform/releases)

- **`PACKER_VERSION`** (optional): Packer version
  - Default: `1.10.0` (defined in pipeline variables)
  - Check [Packer releases](https://github.com/hashicorp/packer/releases)

### Security Scanning

- **`TRIVY_SEVERITY`** (optional): Severity levels to scan
  - Default: `HIGH,CRITICAL`
  - Options: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `UNKNOWN`
  - Can combine: `HIGH,CRITICAL` or `CRITICAL,HIGH,MEDIUM`

- **`TRIVY_EXIT_CODE`** (optional): Whether to fail pipeline on findings
  - Default: `0` (don't fail pipeline)
  - Set to `1` to fail pipeline if vulnerabilities found

### AWS Region

- **`AWS_DEFAULT_REGION`** or **`AWS_REGION`** (optional): AWS region for deployment
  - Default: `us-east-1`
  - Examples: `us-west-2`, `eu-west-1`, `ap-southeast-1`
  - Must be consistent across all AWS-related variables

---

## 🔧 Variable Configuration Steps

### Step 1: Add Required Variables

1. Go to **Settings** → **CI/CD** → **Variables**
2. Click **Add variable**
3. For each required variable:
   - **Key**: Enter variable name (e.g., `AWS_ACCESS_KEY_ID`)
   - **Value**: Enter the value
   - **Type**: Variable
   - **Environment scope**: `*` (all environments)
   - **Protect variable**: ✅ Check (for sensitive data)
   - **Mask variable**: ✅ Check (for sensitive data)
   - **Expand variable reference**: ❌ Unchecked
4. Click **Add variable**

### Step 2: Add Optional Variables (if needed)

Repeat Step 1 for optional variables you want to customize. For optional variables:
- **Protect variable**: ❌ Unchecked (unless sensitive)
- **Mask variable**: ❌ Unchecked (unless sensitive)

---

## ✅ Quick Setup Checklist

Minimum required variables to get started:

- [ ] `AWS_ACCESS_KEY_ID` (Protected + Masked)
- [ ] `AWS_SECRET_ACCESS_KEY` (Protected + Masked)
- [ ] `TF_STATE_BUCKET`

Optional but recommended:

- [ ] `AWS_DEFAULT_REGION` (if not using `us-east-1`)
- [ ] `TF_VARS_FILE` (if not using `dev.tfvars`)
- [ ] `TF_STATE_KEY` (for multi-environment)

---

## 🔍 Testing Variables

After setting variables, test them:

1. Run a pipeline manually
2. Check the `terraform_init` job logs
3. Verify AWS connection is successful:
   ```
   Verifying AWS connection...
   {
     "UserId": "...",
     "Account": "...",
     "Arn": "..."
   }
   ```

---

## 🛡️ Security Best Practices

1. **Never commit secrets** to the repository
2. **Use Protected variables** for sensitive data (AWS keys, passwords)
3. **Use Masked variables** to hide values in logs
4. **Rotate credentials** regularly
5. **Use IAM roles** instead of access keys when possible (requires GitLab Runner on AWS)
6. **Limit variable scope** to specific environments when needed
7. **Review variable access** regularly

---

## 📚 Related Documentation

- [GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)
- [GitLab Protected Variables](https://docs.gitlab.com/ee/ci/variables/#protected-variables)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

---

## 🔄 Variable Reference in Pipeline

The pipeline uses these variables in the following jobs:

| Job | Variables Used |
|-----|----------------|
| `checkout_and_prepare` | None (uses CI built-in variables) |
| `terraform_init` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `TF_STATE_BUCKET`, `TF_STATE_KEY`, `TF_STATE_REGION` |
| `terraform_validate` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` |
| `terraform_plan` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `JENKINS_VERSION`, `JAVA_VERSION`, `TF_VARS_FILE`, `PACKER_VERSION` |
| `terraform_apply` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `JENKINS_VERSION`, `JAVA_VERSION`, `TF_VARS_FILE`, `PACKER_VERSION` |
| `scan_ami` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `TRIVY_SEVERITY`, `TRIVY_EXIT_CODE` |
| `notify` | `AWS_REGION` |

---

**Last Updated**: 2024
**Pipeline Version**: 1.0.0

