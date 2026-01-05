# GitLab CI/CD Pipeline: Automated Jenkins AMI Build and Scan

This guide provides step-by-step instructions to automate the Jenkins Golden AMI creation process using GitLab CI/CD, following the three-stage workflow: **Checkout → Packer Build → Trivy Scan**.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Set Up GitLab Repository](#step-1-set-up-gitlab-repository)
4. [Step 2: Configure GitLab CI/CD Variables](#step-2-configure-gitlab-cicd-variables)
5. [Step 3: Create GitLab CI/CD Configuration](#step-3-create-gitlab-cicd-configuration)
6. [Step 4: Set Up GitLab Runner (If Needed)](#step-4-set-up-gitlab-runner-if-needed)
7. [Step 5: Test the Pipeline](#step-5-test-the-pipeline)
8. [Step 6: Monitor and Troubleshoot](#step-6-monitor-and-troubleshoot)
9. [Pipeline Flow Diagram](#pipeline-flow-diagram)
10. [Advanced Configuration](#advanced-configuration)

---

## Overview

The GitLab CI/CD pipeline automates the complete AMI build process:

```
┌─────────────────────────────────────────────────────────────┐
│                    GITLAB CI/CD PIPELINE                     │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  STAGE I     │    │  STAGE II     │    │  STAGE III   │
│  Checkout    │───▶│ Build AMI     │───▶│ Scan AMI     │
│              │    │  (Packer)     │    │  (Trivy)     │
└──────────────┘    └──────────────┘    └──────────────┘
```

### Stage I: Checkout
- Clones repository
- Prepares playbooks and configuration files
- Sets up build environment

### Stage II: Packer Build
- Initializes Packer
- Builds Golden AMI using Packer
- Applies Ansible playbooks for configuration
- Creates AMI snapshot

### Stage III: Trivy Scan
- Scans the built AMI for security vulnerabilities
- Generates security reports
- Fails pipeline on critical vulnerabilities

---

## Prerequisites

Before starting, ensure you have:

- ✅ **GitLab Account** with a project repository
- ✅ **AWS Account** with appropriate IAM permissions
- ✅ **GitLab Runner** (shared or self-hosted) with Docker executor
- ✅ **AWS CLI** configured (or use GitLab CI/CD variables)
- ✅ **Access to GitLab project** (Maintainer or Owner role)

### Required AWS Permissions

Your AWS credentials need permissions for:
- EC2 (create instances, AMIs, snapshots)
- IAM (read roles)
- S3 (optional, for artifacts)

### Required Tools on GitLab Runner

The runner should have:
- Docker
- Packer (will be installed in pipeline)
- AWS CLI (or use GitLab variables)
- Trivy (will be pulled as Docker image)

---

## Step 1: Set Up GitLab Repository

### 1.1 Push Your Code to GitLab

```bash
# Navigate to your project directory
cd /Users/mac/Documents/DEVOPS-PORTFOLIOS/jenkins-aws-ha-packer

# Initialize git if not already done
git init

# Add GitLab remote (replace with your GitLab URL)
git remote add origin https://gitlab.com/your-username/jenkins-aws-ha-packer.git

# Add all files
git add .

# Commit
git commit -m "Initial commit: Jenkins HA Packer project"

# Push to GitLab
git push -u origin main
```

### 1.2 Verify Repository Structure

Ensure your repository has this structure:
```
jenkins-aws-ha-packer/
├── .gitlab-ci.yml          # (We'll create this)
├── packer/
│   ├── jenkins-ami.pkr.hcl
│   ├── variables.pkr.hcl
│   └── scripts/
│       └── install-jenkins.sh
├── playbooks/
│   └── jenkins-setup.yml
├── jenkins-config/
│   └── ...
└── terraform/
    └── ...
```

---

## Step 2: Configure GitLab CI/CD Variables

### 2.1 Access GitLab CI/CD Variables

1. Go to your GitLab project
2. Navigate to **Settings** → **CI/CD**
3. Expand **Variables** section
4. Click **Add variable**

### 2.2 Add Required Variables

Add the following variables (mark sensitive ones as **Protected** and **Masked**):

| Variable Name | Value | Protected | Masked | Description |
|--------------|-------|-----------|--------|-------------|
| `AWS_ACCESS_KEY_ID` | `your-access-key` | ✅ | ✅ | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | `your-secret-key` | ✅ | ✅ | AWS Secret Key |
| `AWS_DEFAULT_REGION` | `us-east-1` | ❌ | ❌ | AWS Region |
| `AWS_REGION` | `us-east-1` | ❌ | ❌ | AWS Region (alternative) |
| `JENKINS_VERSION` | `2.414.3` | ❌ | ❌ | Jenkins version to install |
| `JAVA_VERSION` | `17` | ❌ | ❌ | Java version |
| `PACKER_VERSION` | `1.10.0` | ❌ | ❌ | Packer version to use |

### 2.3 Optional Variables

| Variable Name | Value | Description |
|--------------|-------|-------------|
| `TRIVY_EXIT_CODE` | `0` | Exit code for Trivy (0 = don't fail on vulnerabilities) |
| `TRIVY_SEVERITY` | `HIGH,CRITICAL` | Severity levels to check |
| `AMI_NAME_PREFIX` | `jenkins-ha` | Prefix for AMI names |

### 2.4 Variable Configuration Screenshot Guide

1. **Variable Key**: Enter the variable name (e.g., `AWS_ACCESS_KEY_ID`)
2. **Value**: Enter the variable value
3. **Type**: Select **Variable** (default)
4. **Environment scope**: Leave as `*` (all environments)
5. **Flags**:
   - ✅ **Protect variable**: Check if it's sensitive
   - ✅ **Mask variable**: Check to hide in logs
   - ❌ **Expand variable reference**: Leave unchecked

Click **Add variable** after each entry.

---

## Step 3: Create GitLab CI/CD Configuration

### 3.1 Create `.gitlab-ci.yml` File

Create a new file `.gitlab-ci.yml` in the root of your repository:

```bash
# Create the file
touch .gitlab-ci.yml
```

### 3.2 Complete GitLab CI/CD Configuration

Copy the following configuration to `.gitlab-ci.yml`:

```yaml
# GitLab CI/CD Pipeline for Jenkins AMI Build and Scan
# Three-stage process: Checkout → Packer Build → Trivy Scan

stages:
  - checkout
  - build
  - scan

variables:
  PACKER_VERSION: "${PACKER_VERSION:-1.10.0}"
  AWS_REGION: "${AWS_DEFAULT_REGION:-us-east-1}"
  JENKINS_VERSION: "${JENKINS_VERSION:-2.414.3}"
  JAVA_VERSION: "${JAVA_VERSION:-17}"
  AMI_NAME_PREFIX: "${AMI_NAME_PREFIX:-jenkins-ha}"
  TRIVY_SEVERITY: "${TRIVY_SEVERITY:-HIGH,CRITICAL}"
  TRIVY_EXIT_CODE: "${TRIVY_EXIT_CODE:-0}"

# ============================================
# STAGE I: CHECKOUT
# ============================================
checkout:
  stage: checkout
  image: alpine:latest
  before_script:
    - apk add --no-cache git
  script:
    - echo "=== STAGE I: CHECKOUT ===" 
    - echo "Repository: $CI_PROJECT_URL"
    - echo "Branch: $CI_COMMIT_REF_NAME"
    - echo "Commit: $CI_COMMIT_SHA"
    - |
      echo "Checking repository structure..."
      ls -la
      echo "Packer directory:"
      ls -la packer/ || echo "Packer directory not found"
      echo "Playbooks directory:"
      ls -la playbooks/ || echo "Playbooks directory not found"
      echo "Jenkins config directory:"
      ls -la jenkins-config/ || echo "Jenkins config directory not found"
    - echo "✅ Checkout completed successfully"
  artifacts:
    paths:
      - packer/
      - playbooks/
      - jenkins-config/
    expire_in: 1 hour
  only:
    - main
    - develop
    - merge_requests

# ============================================
# STAGE II: PACKER BUILD
# ============================================
build_ami:
  stage: build
  image: 
    name: hashicorp/packer:${PACKER_VERSION}
    entrypoint: [""]
  dependencies:
    - checkout
  before_script:
    - echo "=== STAGE II: PACKER BUILD ===" 
    - |
      echo "Installing dependencies..."
      apk add --no-cache \
        python3 \
        py3-pip \
        openssh-client \
        curl \
        unzip \
        git \
        jq
    - |
      echo "Installing Ansible..."
      pip3 install --upgrade pip
      pip3 install ansible
    - |
      echo "Installing AWS CLI..."
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip awscliv2.zip
      ./aws/install
      rm -rf aws awscliv2.zip
    - |
      echo "Configuring AWS credentials..."
      mkdir -p ~/.aws
      echo "[default]" > ~/.aws/credentials
      echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> ~/.aws/credentials
      echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> ~/.aws/credentials
      echo "[default]" > ~/.aws/config
      echo "region = ${AWS_REGION}" >> ~/.aws/config
      echo "output = json" >> ~/.aws/config
    - |
      echo "Verifying AWS connection..."
      aws sts get-caller-identity
    - |
      echo "Verifying Packer installation..."
      packer version
    - |
      echo "Verifying Ansible installation..."
      ansible --version
  script:
    - |
      echo "Navigating to packer directory..."
      cd packer
      pwd
      ls -la
    - |
      echo "Initializing Packer plugins..."
      packer init .
    - |
      echo "Validating Packer configuration..."
      packer validate \
        -var "aws_region=${AWS_REGION}" \
        -var "jenkins_version=${JENKINS_VERSION}" \
        -var "java_version=${JAVA_VERSION}" \
        .
    - |
      echo "Building AMI with Packer..."
      packer build \
        -var "aws_region=${AWS_REGION}" \
        -var "jenkins_version=${JENKINS_VERSION}" \
        -var "java_version=${JAVA_VERSION}" \
        -machine-readable \
        . | tee packer-build.log
    - |
      echo "Extracting AMI ID from manifest..."
      if [ -f manifest.json ]; then
        AMI_ID=$(jq -r '.builds[0].artifact_id' manifest.json | cut -d':' -f2)
        echo "AMI_ID=${AMI_ID}" > ../ami-id.txt
        echo "✅ AMI built successfully: ${AMI_ID}"
      else
        echo "❌ Error: manifest.json not found"
        exit 1
      fi
    - |
      echo "Extracting AMI ID from build log..."
      AMI_ID=$(grep 'artifact,0,id' packer-build.log | cut -d',' -f6 | cut -d':' -f2 || echo "")
      if [ -n "${AMI_ID}" ]; then
        echo "AMI_ID=${AMI_ID}" >> ../ami-id.txt
        echo "AMI ID from log: ${AMI_ID}"
      fi
  artifacts:
    paths:
      - packer/manifest.json
      - packer/packer-build.log
      - ami-id.txt
    expire_in: 1 week
    reports:
      # Store AMI ID for next stage
      dotenv: ami-id.txt
  only:
    - main
    - develop
    - merge_requests
  when: on_success

# ============================================
# STAGE III: TRIVY SCAN
# ============================================
scan_ami:
  stage: scan
  image: 
    name: aquasec/trivy:latest
    entrypoint: [""]
  dependencies:
    - build_ami
  before_script:
    - echo "=== STAGE III: TRIVY SCAN ===" 
    - |
      echo "Installing AWS CLI for Trivy..."
      apk add --no-cache curl unzip
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip awscliv2.zip
      ./aws/install
      rm -rf aws awscliv2.zip
    - |
      echo "Configuring AWS credentials for Trivy..."
      mkdir -p ~/.aws
      echo "[default]" > ~/.aws/credentials
      echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> ~/.aws/credentials
      echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> ~/.aws/credentials
      echo "[default]" > ~/.aws/config
      echo "region = ${AWS_REGION}" >> ~/.aws/config
    - |
      echo "Reading AMI ID from previous stage..."
      if [ -f ami-id.txt ]; then
        source ami-id.txt
        echo "AMI ID: ${AMI_ID}"
      else
        echo "❌ Error: ami-id.txt not found"
        exit 1
      fi
    - |
      echo "Verifying AMI exists in AWS..."
      aws ec2 describe-images \
        --image-ids ${AMI_ID} \
        --region ${AWS_REGION} \
        --query 'Images[0].[ImageId,Name,State]' \
        --output table
  script:
    - |
      echo "Scanning AMI with Trivy..."
      echo "AMI ID: ${AMI_ID}"
      echo "Severity: ${TRIVY_SEVERITY}"
      echo "Exit Code: ${TRIVY_EXIT_CODE}"
    - |
      trivy image \
        --exit-code ${TRIVY_EXIT_CODE} \
        --severity ${TRIVY_SEVERITY} \
        --format table \
        --output trivy-report.txt \
        ${AMI_ID}
    - |
      echo "Generating JSON report..."
      trivy image \
        --exit-code ${TRIVY_EXIT_CODE} \
        --severity ${TRIVY_SEVERITY} \
        --format json \
        --output trivy-report.json \
        ${AMI_ID}
    - |
      echo "Generating HTML report..."
      trivy image \
        --exit-code ${TRIVY_EXIT_CODE} \
        --severity ${TRIVY_SEVERITY} \
        --format template \
        --template '@contrib/html.tpl' \
        --output trivy-report.html \
        ${AMI_ID}
    - |
      echo "✅ Trivy scan completed"
      echo "Summary:"
      cat trivy-report.txt | head -20
  artifacts:
    paths:
      - trivy-report.txt
      - trivy-report.json
      - trivy-report.html
      - ami-id.txt
    reports:
      # GitLab security scanning integration
      sast: trivy-report.json
    expire_in: 30 days
  only:
    - main
    - develop
    - merge_requests
  when: on_success
  allow_failure: false

# ============================================
# OPTIONAL: NOTIFICATION JOB
# ============================================
notify:
  stage: .post
  image: curlimages/curl:latest
  script:
    - |
      echo "=== Pipeline Summary ===" 
      if [ -f ami-id.txt ]; then
        source ami-id.txt
        echo "✅ AMI Built: ${AMI_ID}"
        echo "🔗 View in AWS: https://console.aws.amazon.com/ec2/v2/home?region=${AWS_REGION}#Images:imageId=${AMI_ID}"
      fi
      echo "📊 Pipeline: $CI_PIPELINE_URL"
      echo "🔍 Job: $CI_JOB_URL"
  only:
    - main
    - develop
  when: on_success
```

### 3.3 Save and Commit the Configuration

```bash
# Add the GitLab CI file
git add .gitlab-ci.yml

# Commit
git commit -m "Add GitLab CI/CD pipeline for AMI build and scan"

# Push to GitLab
git push origin main
```

---

## Step 4: Set Up GitLab Runner (If Needed)

### 4.1 Check if Runner is Available

1. Go to **Settings** → **CI/CD**
2. Expand **Runners** section
3. Check if there's an active runner

### 4.2 Use Shared Runners (Recommended for Start)

GitLab provides shared runners. To use them:
1. Go to **Settings** → **CI/CD** → **Runners**
2. Ensure **Shared runners** are enabled
3. The pipeline will use shared runners automatically

### 4.3 Set Up Self-Hosted Runner (Optional)

If you need a self-hosted runner:

```bash
# Install GitLab Runner (Ubuntu/Debian)
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# Register runner
sudo gitlab-runner register

# Follow prompts:
# - GitLab URL: https://gitlab.com/
# - Registration token: (from GitLab project settings)
# - Description: jenkins-ami-builder
# - Tags: packer,aws,ami
# - Executor: docker
# - Docker image: alpine:latest
```

---

## Step 5: Test the Pipeline

### 5.1 Trigger Pipeline Manually

1. Go to **CI/CD** → **Pipelines**
2. Click **Run pipeline**
3. Select branch: `main`
4. Click **Run pipeline**

### 5.2 Monitor Pipeline Execution

1. Click on the pipeline to view stages
2. Watch each job execute:
   - ✅ **checkout**: Should complete quickly
   - ⏳ **build_ami**: Takes 10-20 minutes (AMI build)
   - ⏳ **scan_ami**: Takes 5-10 minutes (Trivy scan)

### 5.3 View Job Logs

Click on any job to see detailed logs:
- Real-time output
- Error messages
- Build progress

### 5.4 Download Artifacts

After pipeline completes:
1. Go to **CI/CD** → **Pipelines**
2. Click on completed pipeline
3. Click **Browse** next to artifacts
4. Download:
   - `ami-id.txt` - AMI ID
   - `trivy-report.html` - Security scan report
   - `manifest.json` - Packer manifest

---

## Step 6: Monitor and Troubleshoot

### 6.1 Common Issues and Solutions

#### Issue 1: AWS Credentials Not Working

**Error**: `Unable to locate credentials`

**Solution**:
- Verify GitLab CI/CD variables are set correctly
- Check if variables are marked as "Protected" (only available on protected branches)
- Ensure AWS credentials have correct permissions

#### Issue 2: Packer Build Fails

**Error**: `Error building AMI`

**Solution**:
- Check Packer logs in job output
- Verify AWS region is correct
- Check instance type availability in region
- Review security group and subnet configurations

#### Issue 3: Trivy Scan Fails

**Error**: `Failed to scan AMI`

**Solution**:
- Verify AMI ID is passed correctly between stages
- Check AWS credentials for Trivy
- Ensure AMI is in same region as configured

#### Issue 4: Ansible Not Found

**Error**: `ansible: command not found`

**Solution**:
- The pipeline installs Ansible in `before_script`
- Check if pip3 install succeeds
- Verify Python3 is available in the image

### 6.2 Debugging Tips

1. **Enable Verbose Logging**:
   ```yaml
   script:
     - packer build -debug ...
   ```

2. **Check Artifacts**:
   - Download `packer-build.log` for detailed Packer output
   - Review `trivy-report.json` for scan details

3. **Test Locally First**:
   ```bash
   # Test Packer build locally
   cd packer
   packer build .
   
   # Test Trivy scan locally
   docker run --rm \
     -e AWS_ACCESS_KEY_ID=... \
     -e AWS_SECRET_ACCESS_KEY=... \
     aquasec/trivy image ami-xxxxx
   ```

---

## Pipeline Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    GITLAB CI/CD PIPELINE                     │
│                  (Triggered on Push/MR)                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STAGE I: CHECKOUT                   │
        │  - Clone repository                  │
        │  - Verify structure                  │
        │  - Prepare artifacts                 │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STAGE II: BUILD AMI (PACKER)          │
        │  - Install dependencies               │
        │  - Configure AWS                      │
        │  - Initialize Packer                  │
        │  - Validate config                    │
        │  - Build AMI                          │
        │  - Extract AMI ID                      │
        │  Output: AMI ID, manifest.json        │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STAGE III: SCAN AMI (TRIVY)           │
        │  - Configure AWS for Trivy            │
        │  - Read AMI ID                        │
        │  - Scan AMI                           │
        │  - Generate reports                   │
        │  Output: Security reports              │
        └───────────────────────────────────────┘
                            │
                            ▼
                    ✅ Pipeline Complete
```

---

## Advanced Configuration

### 7.1 Add Manual Approval Gate

Add before Trivy scan:

```yaml
approve_scan:
  stage: .pre
  script:
    - echo "Waiting for manual approval to proceed with scan..."
  when: manual
  only:
    - main
```

### 7.2 Add Slack Notifications

```yaml
notify_slack:
  stage: .post
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

### 7.3 Parallel AMI Builds for Multiple Regions

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

### 7.4 Cache Packer Plugins

```yaml
cache:
  paths:
    - .packer.d/plugins/
```

---

## Summary Checklist

After completing all steps, verify:

- [ ] GitLab repository is set up
- [ ] All CI/CD variables are configured
- [ ] `.gitlab-ci.yml` is committed and pushed
- [ ] GitLab Runner is available (shared or self-hosted)
- [ ] Pipeline runs successfully
- [ ] AMI is built and available in AWS
- [ ] Trivy scan completes and generates reports
- [ ] Artifacts are downloadable

---

## Next Steps

After successful pipeline execution:

1. **Use the AMI**: Use the AMI ID from `ami-id.txt` in Terraform
2. **Review Security Reports**: Check `trivy-report.html` for vulnerabilities
3. **Update Infrastructure**: Deploy using the new AMI
4. **Schedule Regular Builds**: Set up pipeline schedules for automated builds

---

## Additional Resources

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Packer Documentation](https://developer.hashicorp.com/packer/docs)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [AWS EC2 AMI Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)

---

**Last Updated**: $(date)
**Version**: 1.0.0

