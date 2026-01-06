# GitHub Actions Quick Start Guide

## Quick Setup Checklist

### ✅ Step 1: Add GitHub Secrets (Required)

Go to: **Repository Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret Name | Value |
|------------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Access Key |

### ✅ Step 2: Verify Repository Structure

Ensure these directories exist:
```
.github/workflows/golden-ami-pipeline.yml  ✅
packer/jenkins-ami.pkr.hcl                 ✅
playbooks/jenkins-setup.yml                ✅
terraform/main/                            ✅
```

### ✅ Step 3: Commit and Push

```bash
git add .github/workflows/golden-ami-pipeline.yml
git commit -m "Add GitHub Actions workflow for Golden AMI pipeline"
git push origin main
```

### ✅ Step 4: Run the Pipeline

**Option A: Automatic** - Push changes to `main` or `develop` branch

**Option B: Manual** - Go to **Actions** tab → **Golden AMI Build and Deploy Pipeline** → **Run workflow**

---

## Workflow Stages Overview

| Stage | Name | Tool | Duration | Status |
|-------|------|------|----------|--------|
| **I** | Checkout | Git | ~30s | ✅ Always runs |
| **II** | Build AMI | Packer + Ansible | ~10-15 min | ✅ Runs on push/manual |
| **III** | Scan AMI | Trivy | ~2-5 min | ✅ Runs after AMI build |
| **IV** | Deploy Infrastructure | Terraform | ~5-10 min | ⚠️ Manual trigger only |
| **V** | Post-Deployment | Shell Scripts | ~2-3 min | ✅ Runs after deployment |

---

## Workflow Flow Diagram

```
┌─────────────────────────────────────────┐
│  STAGE I: Checkout                      │
│  - Checkout repository                  │
│  - Set build metadata                   │
│  - Upload artifact                      │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  STAGE II: Build AMI                    │
│  - Install Packer & Ansible             │
│  - Base AMI → Temp EC2                  │
│  - Ansible Provisioner (playbook)       │
│  - Install: Jenkins, Java, Ubuntu       │
│  - Create Golden AMI                    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  STAGE III: Scan AMI                    │
│  - Read AMI ID                          │
│  - Trivy scan (HIGH,CRITICAL)           │
│  - Generate reports (JSON, HTML, TXT)    │
│  - Pass/Fail decision                   │
└──────────────┬──────────────────────────┘
               │
               ▼ (if scan passes & manual trigger)
┌─────────────────────────────────────────┐
│  STAGE IV: Deploy Infrastructure        │
│  - Terraform Init/Plan/Apply            │
│  - Create: VPC, EFS, ELB, ASG           │
│  - Launch Template (uses Golden AMI)    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  STAGE V: Post-Deployment               │
│  - Wait for instances                   │
│  - Run post-deployment scripts          │
│  - Verify deployment                    │
└─────────────────────────────────────────┘
```

---

## Key Files and Locations

| File | Purpose | Location |
|------|---------|----------|
| Workflow file | GitHub Actions pipeline | `.github/workflows/golden-ami-pipeline.yml` |
| Packer config | AMI build configuration | `packer/jenkins-ami.pkr.hcl` |
| Ansible playbook | Jenkins configuration | `playbooks/jenkins-setup.yml` |
| Terraform config | Infrastructure as code | `terraform/main/` |

---

## Environment Variables

The workflow uses these environment variables (can be customized):

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for deployment |
| `PACKER_VERSION` | `1.10.0` | Packer version |
| `TERRAFORM_VERSION` | `1.6.0` | Terraform version |
| `TRIVY_VERSION` | `latest` | Trivy version |

**Repository Variables** (optional, set in GitHub Settings):
- `JENKINS_VERSION` (default: `2.414.3`)
- `JAVA_VERSION` (default: `17`)
- `TRIVY_SEVERITY` (default: `HIGH,CRITICAL`)
- `TRIVY_EXIT_CODE` (default: `1`)

---

## Manual Workflow Trigger Options

When manually triggering the workflow, you can configure:

1. **Build AMI**: `true` / `false`
   - Set to `false` to skip AMI build and use existing AMI

2. **Deploy Infrastructure**: `true` / `false`
   - Set to `true` to deploy infrastructure after AMI scan

3. **Environment**: `dev` / `staging` / `prod`
   - Selects the deployment environment

---

## Artifacts Generated

After each run, you can download:

1. **Repository** - Complete codebase
2. **AMI Metadata** - AMI ID, manifest, logs
3. **Trivy Reports** - Security scan reports (JSON, HTML, TXT)
4. **Terraform State** - Infrastructure state (if deployed)

**To download**: Go to workflow run → Scroll to **Artifacts** section

---

## Common Commands

### View Workflow Logs
```bash
# In GitHub UI: Actions → Select workflow run → Click on job → View logs
```

### Check AMI in AWS
```bash
aws ec2 describe-images --image-ids ami-xxxxx --region us-east-1
```

### View Trivy Report
```bash
# Download artifact: trivy-reports
# Open: trivy-report.html in browser
```

### Check Infrastructure
```bash
cd terraform/main
terraform output
```

---

## Troubleshooting Quick Fixes

| Issue | Quick Fix |
|-------|-----------|
| **Packer build fails** | Check AWS credentials, verify base AMI exists |
| **Trivy scan fails** | Check AMI is accessible, review scan reports |
| **Terraform fails** | Check IAM permissions, review Terraform plan |
| **AMI ID not found** | Verify Stage II completed, check artifacts |

---

## Next Steps After Setup

1. ✅ Test pipeline with a small change
2. ✅ Review Trivy scan results
3. ✅ Deploy to dev environment
4. ✅ Set up monitoring and alerts
5. ✅ Document any customizations

---

## Support

For detailed information, see:
- **Full Guide**: `GITHUB-ACTIONS-AUTOMATION-GUIDE.md`
- **Workflow Steps**: `COMPLETE-WORKFLOW-STEP-BY-STEP.md`

---

## Summary

The GitHub Actions workflow automates:

1. ✅ **Checkout** - Get code and playbooks
2. ✅ **Build AMI** - Packer + Ansible → Golden AMI
3. ✅ **Scan AMI** - Trivy security scan
4. ✅ **Deploy** - Terraform infrastructure
5. ✅ **Configure** - Post-deployment setup

**Ready to go!** Just add your AWS credentials as GitHub Secrets and push to trigger the pipeline.

