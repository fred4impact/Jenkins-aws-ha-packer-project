# GitHub Actions Automation Guide for Golden AMI Pipeline

This guide provides step-by-step instructions to automate the complete Golden AMI workflow using GitHub Actions, matching the exact flow shown in the workflow diagrams.

## Workflow Overview

The GitHub Actions pipeline automates the following stages:

```
┌─────────────────────────────────────────────────────────────┐
│              GITHUB ACTIONS PIPELINE                          │
│         (Orchestrates the entire process)                    │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   STAGE I    │    │   STAGE II   │    │  STAGE III   │
│  Checkout    │───▶│  Build AMI   │───▶│  Scan AMI    │
│  Playbook    │    │  (Packer)    │    │  (Trivy)     │
└──────────────┘    └──────────────┘    └──────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │   STAGE IV   │
                    │ Deploy Infra │
                    │ (Terraform)  │
                    └──────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │   STAGE V    │
                    │ Post-Deploy  │
                    │(Shell Scripts)│
                    └──────────────┘
```

## Stage-by-Stage Breakdown

### **STAGE I: Checkout Playbook and Code**

**Purpose**: Retrieve the repository containing Packer configurations, Ansible playbooks, and Terraform code.

**What Happens**:
- Checks out the repository code
- Verifies playbook structure exists
- Sets build metadata (timestamp, build ID)
- Uploads repository as artifact for subsequent stages

**GitHub Actions Implementation**:
```yaml
- Checkout repository
- Set build metadata (timestamp, build ID)
- Verify playbook structure
- Upload repository as artifact
```

**Output**: Repository code available for all subsequent stages

---

### **STAGE II: Build Golden AMI with Packer**

**Purpose**: Create a standardized, pre-configured Amazon Machine Image (AMI) using Packer with Ansible provisioning.

**What Happens**:
- Installs Packer and Ansible
- Initializes Packer plugins
- Validates Packer configuration
- Launches temporary EC2 instance from base Ubuntu AMI
- Provisions instance with:
  - Jenkins installation
  - Java installation
  - OS updates (via Ansible)
  - Jenkins configuration (via Ansible playbook)
- Creates Golden AMI snapshot
- Terminates temporary instance
- Extracts and stores AMI ID

**Process Flow** (matching the diagram):
```
Base AMI (Ubuntu) 
  → Temp EC2 Instance 
  → Ansible Provisioner (playbook) 
  → Install Jenkins, Java, Ubuntu updates 
  → Create Snapshot 
  → Golden AMI
```

**GitHub Actions Implementation**:
```yaml
- Install Packer and Ansible
- Initialize Packer plugins
- Validate Packer configuration
- Build AMI with Packer (uses Ansible provisioner)
- Extract AMI ID from manifest
- Verify AMI exists in AWS
- Tag AMI with build information
```

**Configuration Files Used**:
- `packer/jenkins-ami.pkr.hcl` - Packer configuration
- `playbooks/jenkins-setup.yml` - Ansible playbook
- `playbooks/roles/jenkins/` - Jenkins configuration roles
- `playbooks/roles/security/` - Security hardening roles

**Output**: Golden AMI ID (e.g., `ami-0abc123def456789`)

---

### **STAGE III: Scan Golden AMI with Trivy**

**Purpose**: Security scanning of the Golden AMI to identify vulnerabilities before deployment.

**What Happens**:
- Reads AMI ID from previous stage
- Verifies AMI exists in AWS
- Runs Trivy scan on the AMI
- Generates multiple report formats:
  - Table format (console output)
  - JSON format (for automation)
  - HTML format (for human review)
- Checks for HIGH and CRITICAL severity vulnerabilities
- Fails pipeline if critical issues found
- Uploads reports as artifacts

**Process Flow**:
```
Golden AMI 
  → Trivy Scanner 
  → Vulnerability Report 
  → Pass/Fail Decision
```

**GitHub Actions Implementation**:
```yaml
- Read AMI ID from previous stage
- Configure AWS credentials for Trivy
- Verify AMI exists
- Scan AMI with Trivy (table format)
- Generate JSON report
- Generate HTML report
- Upload reports as artifacts
- Upload to GitHub Security (SARIF)
- Fail if critical vulnerabilities found
```

**Scan Command**:
```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION=us-east-1 \
  aquasec/trivy:latest \
  image \
  --format json \
  --output trivy-report.json \
  --severity HIGH,CRITICAL \
  ami-0abc123def456789
```

**Output**: 
- Security scan reports (JSON, HTML, TXT)
- Pass/Fail status for pipeline

---

### **STAGE IV: Deploy Infrastructure with Terraform**

**Purpose**: Provision and manage the complete AWS infrastructure required for High Availability Jenkins.

**What Happens**:
- Reads Golden AMI ID from previous stages
- Initializes Terraform
- Validates Terraform configuration
- Creates Terraform plan
- Deploys infrastructure:
  - **Network**: VPC, Subnets, Internet Gateway, NAT Gateways
  - **EFS**: Elastic File System for shared Jenkins home
  - **ELB**: Application Load Balancer for traffic distribution
  - **ASG**: Auto Scaling Group with Launch Template
  - **Launch Template**: Uses Golden AMI from Stage II
- Extracts infrastructure outputs (ALB DNS, EFS ID)

**What Gets Created**:
- ✅ VPC with public/private subnets across multiple AZs
- ✅ Internet Gateway and NAT Gateways
- ✅ Security Groups
- ✅ EFS file system with mount targets
- ✅ Application Load Balancer
- ✅ Auto Scaling Group (min: 2, max: 5, desired: 2)
- ✅ Launch Template (uses Golden AMI)
- ✅ IAM roles and policies
- ✅ CloudWatch alarms

**GitHub Actions Implementation**:
```yaml
- Read AMI ID from previous stage
- Configure AWS credentials
- Setup Terraform
- Terraform Init
- Terraform Validate
- Terraform Plan (with AMI ID)
- Terraform Apply
- Get Terraform outputs (ALB DNS, EFS ID)
```

**Output**: 
- Complete AWS infrastructure
- ALB DNS name
- EFS file system ID

---

### **STAGE V: Post-Deployment Configuration**

**Purpose**: Final configuration and verification after infrastructure is deployed.

**What Happens**:
- Waits for Jenkins instances to be ready
- Runs post-deployment shell scripts
- Verifies deployment health
- Displays deployment summary

**Post-Deployment Tasks**:
- Wait for Jenkins to be accessible via ALB
- Run configuration scripts (if any)
- Verify EFS mounting
- Health checks
- Display deployment URLs

**GitHub Actions Implementation**:
```yaml
- Wait for instances to be ready
- Run post-deployment scripts
- Verify deployment
- Display deployment summary
```

**Output**: Fully configured and operational Jenkins infrastructure

---

## Setup Instructions

### **Step 1: Repository Setup**

1. **Ensure your repository structure matches**:
   ```
   repository/
   ├── .github/
   │   └── workflows/
   │       └── golden-ami-pipeline.yml
   ├── packer/
   │   ├── jenkins-ami.pkr.hcl
   │   └── scripts/
   ├── playbooks/
   │   ├── jenkins-setup.yml
   │   └── roles/
   ├── terraform/
   │   └── main/
   └── scripts/
   ```

2. **Commit the workflow file**:
   ```bash
   git add .github/workflows/golden-ami-pipeline.yml
   git commit -m "Add GitHub Actions workflow for Golden AMI pipeline"
   git push origin main
   ```

### **Step 2: Configure GitHub Secrets**

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**

Add the following secrets:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |

**Optional Secrets** (if you want to customize):
- You can also set repository variables instead of hardcoding:
  - `JENKINS_VERSION` (default: `2.414.3`)
  - `JAVA_VERSION` (default: `17`)
  - `TRIVY_EXIT_CODE` (default: `1`)
  - `TRIVY_SEVERITY` (default: `HIGH,CRITICAL`)

### **Step 3: Configure AWS IAM Permissions**

Create an IAM user or role with the following permissions:

**Minimum Required Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "iam:PassRole",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "efs:*",
        "elasticloadbalancing:*",
        "autoscaling:*",
        "logs:*",
        "cloudwatch:*",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "*"
    }
  ]
}
```

**Best Practice**: Use more restrictive policies in production, scoped to specific resources.

### **Step 4: Configure Terraform Variables**

1. **Navigate to Terraform directory**:
   ```bash
   cd terraform/main
   ```

2. **Create `terraform.tfvars`** (or use environment variables):
   ```hcl
   project_name = "ha-jenkins"
   environment  = "dev"
   aws_region   = "us-east-1"
   
   vpc_cidr           = "10.0.0.0/16"
   public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
   private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
   
   instance_type = "t3.medium"
   key_name      = "your-keypair-name"
   
   asg_min_size         = 2
   asg_max_size         = 5
   asg_desired_capacity = 2
   ```

3. **Commit the configuration** (or use GitHub Secrets for sensitive values)

### **Step 5: Trigger the Pipeline**

#### **Option A: Automatic Trigger (on Push)**
The workflow automatically triggers on:
- Push to `main` or `develop` branches
- Changes to `packer/`, `playbooks/`, `terraform/`, or `.github/workflows/` directories

#### **Option B: Manual Trigger (Workflow Dispatch)**
1. Go to **Actions** tab in GitHub
2. Select **Golden AMI Build and Deploy Pipeline**
3. Click **Run workflow**
4. Configure options:
   - **Build AMI**: `true` or `false`
   - **Deploy Infrastructure**: `true` or `false`
   - **Environment**: `dev`, `staging`, or `prod`
5. Click **Run workflow**

#### **Option C: Pull Request Trigger**
The workflow also runs on pull requests to `main` or `develop` branches (for validation only).

---

## Workflow Execution Flow

### **Complete Execution Sequence**

```
1. GitHub Actions Pipeline Triggers
   ↓
2. STAGE I: Checkout
   - Checkout repository
   - Set build metadata
   - Upload repository artifact
   ↓
3. STAGE II: Build AMI
   - Install Packer & Ansible
   - Initialize Packer plugins
   - Validate configuration
   - Build Golden AMI (Base AMI → Temp EC2 → Ansible → Golden AMI)
   - Extract AMI ID
   - Tag AMI
   ↓
4. STAGE III: Scan AMI
   - Read AMI ID
   - Scan with Trivy
   - Generate reports (JSON, HTML, TXT)
   - Check for vulnerabilities
   - Fail if critical issues found
   ↓
5. STAGE IV: Deploy Infrastructure (if enabled)
   - Read AMI ID
   - Initialize Terraform
   - Plan infrastructure
   - Apply infrastructure (VPC, EFS, ELB, ASG)
   - Get outputs (ALB DNS, EFS ID)
   ↓
6. STAGE V: Post-Deployment (if infrastructure deployed)
   - Wait for instances to be ready
   - Run post-deployment scripts
   - Verify deployment
   ↓
7. Notification
   - Display pipeline summary
   - Show AMI ID and deployment URLs
```

---

## Monitoring and Artifacts

### **Viewing Workflow Runs**

1. Go to **Actions** tab in GitHub
2. Click on a workflow run to see:
   - Job status for each stage
   - Logs for each step
   - Artifacts generated
   - Duration of each stage

### **Artifacts Generated**

The workflow generates the following artifacts:

1. **Repository** (Stage I)
   - Complete repository code
   - Retention: 7 days

2. **AMI Metadata** (Stage II)
   - `ami-id.txt` - AMI ID and name
   - `manifest.json` - Packer manifest
   - `packer.log` - Packer build logs
   - Retention: 30 days

3. **Trivy Reports** (Stage III)
   - `trivy-report.txt` - Table format
   - `trivy-report.json` - JSON format
   - `trivy-report.html` - HTML format
   - `ami-id.txt` - AMI ID
   - Retention: 30 days

4. **Terraform State** (Stage IV, optional)
   - Terraform state files
   - Retention: 90 days

### **Downloading Artifacts**

1. Go to the workflow run
2. Scroll to the **Artifacts** section
3. Click on an artifact to download

---

## Customization Options

### **1. Modify Trigger Conditions**

Edit `.github/workflows/golden-ami-pipeline.yml`:

```yaml
on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'packer/**'      # Only trigger on Packer changes
      - 'playbooks/**'   # Only trigger on Ansible changes
```

### **2. Change AWS Region**

Edit the `env` section:
```yaml
env:
  AWS_REGION: us-west-2  # Change to your preferred region
```

### **3. Customize Trivy Severity**

Set repository variable `TRIVY_SEVERITY`:
- Options: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`
- Default: `HIGH,CRITICAL`

### **4. Add Notifications**

Add notification steps (Slack, email, etc.):

```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Pipeline completed'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### **5. Add Approval Gates**

Add environment protection rules:
1. Go to **Settings** → **Environments**
2. Create environment (e.g., `prod`)
3. Add required reviewers
4. The workflow will wait for approval before deploying

---

## Troubleshooting

### **Common Issues**

#### **1. Packer Build Fails**

**Symptoms**: Stage II fails with Packer errors

**Solutions**:
- Check AWS credentials are correct
- Verify base AMI exists in the region
- Check Packer configuration syntax
- Review Packer logs in artifacts

#### **2. Trivy Scan Fails**

**Symptoms**: Stage III fails with scan errors

**Solutions**:
- Verify AMI exists and is accessible
- Check AWS credentials for Trivy
- Review Trivy reports for specific vulnerabilities
- Adjust `TRIVY_EXIT_CODE` to `0` to allow warnings

#### **3. Terraform Apply Fails**

**Symptoms**: Stage IV fails during Terraform apply

**Solutions**:
- Check Terraform configuration
- Verify IAM permissions
- Review Terraform plan output
- Check for resource conflicts

#### **4. AMI ID Not Found**

**Symptoms**: Subsequent stages can't find AMI ID

**Solutions**:
- Verify Stage II completed successfully
- Check `ami-id.txt` artifact
- Ensure artifact upload/download works

---

## Best Practices

### **1. Security**

- ✅ Use GitHub Secrets for sensitive data
- ✅ Rotate AWS credentials regularly
- ✅ Use least privilege IAM policies
- ✅ Enable Trivy scanning before deployment
- ✅ Review security reports before production

### **2. Cost Optimization**

- ✅ Use appropriate instance types
- ✅ Clean up old AMIs regularly
- ✅ Use spot instances for temporary builds (if applicable)
- ✅ Monitor AWS costs

### **3. Reliability**

- ✅ Test in dev environment first
- ✅ Use infrastructure as code (Terraform)
- ✅ Version control all configurations
- ✅ Tag resources for tracking

### **4. Monitoring**

- ✅ Set up CloudWatch alarms
- ✅ Monitor pipeline execution times
- ✅ Track AMI build success rates
- ✅ Review Trivy scan trends

---

## Comparison: Jenkins vs GitHub Actions

| Feature | Jenkins Pipeline | GitHub Actions |
|---------|-----------------|----------------|
| **Orchestration** | Jenkinsfile (Groovy) | YAML workflow files |
| **Hosting** | Self-hosted or Cloud | GitHub-hosted runners |
| **Integration** | Requires plugins | Native GitHub integration |
| **Cost** | Infrastructure costs | Free for public repos, paid for private |
| **Scalability** | Manual scaling | Auto-scaling runners |
| **UI** | Jenkins web UI | GitHub Actions UI |

---

## Next Steps

1. ✅ Set up GitHub Secrets
2. ✅ Configure AWS IAM permissions
3. ✅ Test the pipeline with a small change
4. ✅ Review Trivy scan results
5. ✅ Deploy to dev environment
6. ✅ Monitor and optimize

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Packer Documentation](https://www.packer.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Terraform Documentation](https://www.terraform.io/docs)

---

## Summary

This GitHub Actions workflow automates the complete Golden AMI build and deployment process:

1. **Checkout** - Retrieves code and playbooks
2. **Build AMI** - Creates Golden AMI with Packer and Ansible
3. **Scan AMI** - Security scanning with Trivy
4. **Deploy Infrastructure** - Provisions AWS infrastructure with Terraform
5. **Post-Deployment** - Final configuration and verification

The workflow matches the exact flow shown in your workflow diagrams and provides a modern, cloud-native alternative to Jenkins pipelines.

