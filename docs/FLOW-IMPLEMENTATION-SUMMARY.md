# Flow Implementation Summary

This document summarizes the changes made to align the project with the flow shown in the images.

---

## ✅ Changes Implemented

### 1. Created Terraform-Packer Integration (`terraform/main/packer-build.tf`)

This file implements the flow where:
- **EFS is created first** (via `module.efs`)
- **Terraform calls Packer** with EFS ID using `null_resource` with `local-exec`
- **Packer builds AMI** with EFS ID as a variable
- **AMI ID is extracted** from Packer manifest and used in ASG

**Key Features:**
- Creates `jenkinsrole.tar` automatically (as shown in Image 1)
- Passes EFS ID to Packer build command
- Extracts AMI ID from manifest.json
- Triggers rebuild when dependencies change

### 2. Updated Packer Variables (`packer/variables.pkr.hcl`)

Added:
- `efs_id` - EFS File System ID (from Terraform)
- `aws_access_key` - AWS credentials (optional)
- `aws_secret_key` - AWS credentials (optional)

### 3. Updated Packer Configuration (`packer/jenkins-ami.pkr.hcl`)

Added provisioners to match images:
- **File provisioner**: Copies `jenkinsrole.tar` to `/home/ubuntu/` (Image 4)
- **File provisioner**: Copies `setup.sh` to `/home/ubuntu/` (Image 4)
- **Shell provisioner**: Extracts tar and runs `setup.sh` with EFS ID (Image 4)

### 4. Created setup.sh Script (`packer/scripts/setup.sh`)

Script that:
- Receives EFS ID as parameter (as shown in Image 4)
- Stores EFS ID for later use
- Extracts `jenkinsrole.tar`
- Sets up environment

### 5. Updated Terraform Variables (`terraform/main/variables.tf`)

Added:
- `aws_access_key` - For Packer build
- `aws_secret_key` - For Packer build
- `build_ami_with_packer` - Toggle to build AMI or use existing

### 6. Updated Terraform Main (`terraform/main/main.tf`)

Modified ASG module to:
- Use dynamically built AMI when `build_ami_with_packer = true`
- Fall back to provided AMI ID if build fails or is disabled
- Add proper dependencies

---

## 📋 Complete Flow (As Per Images)

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    GITLAB CI/CD PIPELINE                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STAGE I: CHECKOUT                     │
        │  - Clone repository                    │
        │  - Create jenkinsrole.tar              │
        │    (tar -cvf jenkinsrole.tar           │
        │     jenkins.yml roles)                 │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STAGE II: TERRAFORM + PACKER         │
        │                                        │
        │  1. Terraform Init                     │
        │     terraform init                    │
        │                                        │
        │  2. Terraform Validate                │
        │     terraform validate                │
        │                                        │
        │  3. Terraform Plan                    │
        │     terraform plan -out testplan      │
        │                                        │
        │  4. Terraform Apply                   │
        │     terraform apply -auto-approve     │
        │     ├─ Creates EFS                    │
        │     ├─ Calls Packer with EFS ID       │
        │     │  (null_resource)                │
        │     ├─ Packer builds AMI              │
        │     │  ├─ Copies jenkinsrole.tar     │
        │     │  ├─ Copies setup.sh             │
        │     │  └─ Runs setup.sh ${efsid}     │
        │     └─ Uses AMI in ASG                │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STAGE III: TRIVY SCAN                │
        │  - Scan built AMI                     │
        │  - Generate reports                   │
        └───────────────────────────────────────┘
```

---

## 🔄 Step-by-Step Execution Flow

### Step 1: Create EFS (Terraform)
```hcl
module "efs" {
  source = "../modules/efs"
  # ... creates EFS
}
```

### Step 2: Build AMI with Packer (Called from Terraform)
```hcl
resource "null_resource" "build_jenkins_ami" {
  depends_on = [module.efs]
  
  provisioner "local-exec" {
    command = <<-EOT
      cd packer
      # Create jenkinsrole.tar
      tar -cvf jenkinsrole.tar ../playbooks/jenkins-setup.yml ../playbooks/roles
      
      # Build AMI with EFS ID
      packer build -var efsid=${module.efs.efs_id} jenkins-ami.pkr.hcl
    EOT
  }
}
```

### Step 3: Packer Build Process
1. **File Provisioner**: Copy `jenkinsrole.tar` → `/home/ubuntu/`
2. **File Provisioner**: Copy `setup.sh` → `/home/ubuntu/`
3. **Shell Provisioner**: Extract tar, run `setup.sh ${efsid}`
4. **Output**: AMI ID in `manifest.json`

### Step 4: Extract AMI ID
```hcl
data "external" "packer_ami_id" {
  program = ["bash", "-c", "jq -r '.builds[0].artifact_id' manifest.json"]
}
```

### Step 5: Use AMI in ASG
```hcl
module "asg" {
  ami_id = data.external.packer_ami_id.result.ami_id
  efs_id = module.efs.efs_id
  # ...
}
```

---

## 📝 Usage Instructions

### Option 1: Build AMI Automatically (Recommended)

```hcl
# terraform/main/terraform.tfvars
build_ami_with_packer = true
aws_access_key        = "your-key"      # Optional if using IAM role
aws_secret_key        = "your-secret"   # Optional if using IAM role
jenkins_ami_id        = ""              # Leave empty, will be built
```

Then run:
```bash
cd terraform/main
terraform init
terraform plan
terraform apply
```

### Option 2: Use Existing AMI

```hcl
# terraform/main/terraform.tfvars
build_ami_with_packer = false
jenkins_ami_id        = "ami-xxxxxxxxx"
```

---

## 🎯 Key Files Modified/Created

1. ✅ `terraform/main/packer-build.tf` - **NEW** - Terraform-Packer integration
2. ✅ `packer/variables.pkr.hcl` - **UPDATED** - Added EFS ID and AWS credentials
3. ✅ `packer/jenkins-ami.pkr.hcl` - **UPDATED** - Added file provisioners for tar and setup.sh
4. ✅ `packer/scripts/setup.sh` - **NEW** - Setup script that receives EFS ID
5. ✅ `terraform/main/variables.tf` - **UPDATED** - Added Packer-related variables
6. ✅ `terraform/main/main.tf` - **UPDATED** - Uses dynamically built AMI

---

## ⚠️ Important Notes

1. **EFS ID is passed to Packer** but EFS is typically mounted at **runtime** (in user-data.sh), not during AMI build
2. **jenkinsrole.tar** is created automatically by Terraform before calling Packer
3. **setup.sh** receives EFS ID and stores it for later use
4. **AMI build happens BEFORE** ASG is created (due to dependencies)
5. **Trivy scan** should happen after AMI is built (in GitLab CI/CD Stage III)

---

## 🚀 Next Steps

1. **Test the flow locally:**
   ```bash
   cd terraform/main
   terraform init
   terraform plan
   terraform apply
   ```

2. **Update GitLab CI/CD** to follow this flow:
   - Stage I: Checkout + Create jenkinsrole.tar
   - Stage II: Terraform Apply (creates EFS, builds AMI, deploys infrastructure)
   - Stage III: Trivy Scan

3. **Verify:**
   - EFS is created first
   - Packer receives EFS ID
   - AMI is built successfully
   - AMI ID is used in ASG
   - Infrastructure deploys correctly

---

## 📚 References

- **Image 1**: Jenkins pipeline steps (tar, terraform commands)
- **Image 2**: Terraform calling Packer with EFS ID
- **Image 3**: Packer configuration with variables
- **Image 4**: Packer provisioners (file and shell)
- **Image 5**: AMI Pipeline flow diagram

---

**Status**: ✅ Implementation Complete
**Last Updated**: $(date)

