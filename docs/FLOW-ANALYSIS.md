# Flow Analysis: Jenkins AMI Build Pipeline

This document analyzes the current flow and compares it with the desired flow shown in the images.

---

## Current Flow vs Desired Flow

### Current Flow (As Implemented)
```
1. Build AMI with Packer (standalone)
   ↓
2. Get AMI ID
   ↓
3. Deploy Infrastructure with Terraform
   - Creates VPC, EFS, ALB, ASG
   - Uses pre-built AMI ID
```

### Desired Flow (From Images)
```
1. Create EFS with Terraform
   ↓
2. Terraform calls Packer with EFS ID
   ↓
3. Packer builds AMI (with EFS ID variable)
   ↓
4. Terraform uses the built AMI
   ↓
5. Trivy scans the AMI
```

---

## Key Differences

### Image 1: Jenkins Pipeline Steps
Shows:
- `tar -cvf jenkinsrole.tar jenkins.yml roles` - Packaging Ansible roles
- Terraform commands: `init`, `validate`, `plan`, `apply`

### Image 2: Terraform Calling Packer
Shows:
```hcl
provider "aws" {
  region = "ap-south-1"
}

data "aws_efs_file_system" "myefs" {
  tags = {
    Name = "jrp"
  }
}

resource "null_resource" "script_file" {
  provisioner "local-exec" {
    command = "packer build -var efsid=${data.aws_efs_file_system.myefs.id} aws-ami.json"
  }
}
```

**Key Points:**
- EFS is created/retrieved FIRST
- Terraform uses `null_resource` with `local-exec` to call Packer
- EFS ID is passed to Packer as a variable

### Image 3: Packer Configuration
Shows:
- Packer uses variables: `{{user 'aws_access_key'}}`, `{{user 'aws_secret_key'}}`
- AMI name: `wezvatech-jenkinsmaster-{{timestamp}}`
- Region: `ap-south-1`
- Source AMI: `ami-02521d90e7410d9f0`
- Security Group: `sg-0a781bd43a7ce089e`
- SSH username: `ubuntu`

### Image 4: Packer Provisioners
Shows:
- File provisioner: Copy `jenkinsrole.tar` to `/home/ubuntu/`
- File provisioner: Copy `setup.sh` to `/home/ubuntu/`
- Shell provisioner: Execute `./setup.sh {{user 'efsid'}}`

**Key Points:**
- `jenkinsrole.tar` contains Ansible roles
- `setup.sh` script receives EFS ID as parameter
- EFS ID is used during AMI build process

### Image 5: AMI Pipeline Flow
Shows:
1. **Create EFS**
2. **AMI Pipeline:**
   - Call Terraform
   - Terraform calls Packer with EFS ID
   - Packer creates temp EC2, Installs Ansible

---

## Recommended Flow Implementation

Based on the images, here's the recommended flow:

### Stage 1: Create EFS (Terraform)
```hcl
# terraform/main/main.tf
module "efs" {
  source = "../modules/efs"
  # ... EFS configuration
}

# Output EFS ID for Packer
output "efs_id" {
  value = module.efs.efs_id
}
```

### Stage 2: Build AMI with Packer (Called from Terraform)
```hcl
# terraform/main/packer-build.tf
resource "null_resource" "build_ami" {
  depends_on = [module.efs]

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../../packer && \
      packer build \
        -var "efs_id=${module.efs.efs_id}" \
        -var "aws_region=${var.aws_region}" \
        -var "jenkins_version=${var.jenkins_version}" \
        -var "java_version=${var.java_version}" \
        -var "aws_access_key=${var.aws_access_key}" \
        -var "aws_secret_key=${var.aws_secret_key}" \
        jenkins-ami.pkr.hcl
    EOT
  }

  triggers = {
    efs_id = module.efs.efs_id
    packer_config = filemd5("${path.module}/../../packer/jenkins-ami.pkr.hcl")
  }
}

# Read AMI ID from Packer manifest
data "external" "ami_id" {
  depends_on = [null_resource.build_ami]
  program = ["bash", "-c", <<-EOT
    cd ${path.module}/../../packer
    if [ -f manifest.json ]; then
      AMI_ID=$(jq -r '.builds[0].artifact_id' manifest.json | cut -d':' -f2)
      echo "{\"ami_id\":\"$AMI_ID\"}"
    else
      echo "{\"ami_id\":\"\"}"
    fi
  EOT
  ]
}
```

### Stage 3: Use AMI in ASG
```hcl
# terraform/main/main.tf
module "asg" {
  source = "../modules/asg"
  
  ami_id = data.external.ami_id.result.ami_id  # Use dynamically built AMI
  efs_id = module.efs.efs_id
  # ... other configuration
}
```

---

## Required Changes to Current Project

### 1. Create Packer Build Terraform Resource

Create `terraform/main/packer-build.tf`:

```hcl
# Packer Build Resource
resource "null_resource" "build_jenkins_ami" {
  depends_on = [module.efs]

  triggers = {
    efs_id           = module.efs.efs_id
    packer_config    = filemd5("${path.module}/../../packer/jenkins-ami.pkr.hcl")
    install_script   = filemd5("${path.module}/../../packer/scripts/install-jenkins.sh")
    jenkins_config   = filemd5("${path.module}/../../packer/../jenkins-config/jenkins-ha-config.xml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../../packer
      
      # Create jenkinsrole.tar if it doesn't exist
      if [ ! -f jenkinsrole.tar ]; then
        echo "Creating jenkinsrole.tar..."
        tar -cvf jenkinsrole.tar ../playbooks/jenkins-setup.yml ../playbooks/roles
      fi
      
      # Build AMI with Packer
      packer build \
        -var "efs_id=${module.efs.efs_id}" \
        -var "aws_region=${var.aws_region}" \
        -var "jenkins_version=${var.jenkins_version}" \
        -var "java_version=${var.java_version}" \
        -var "aws_access_key=${var.aws_access_key}" \
        -var "aws_secret_key=${var.aws_secret_key}" \
        jenkins-ami.pkr.hcl
    EOT
  }
}

# Extract AMI ID from Packer manifest
data "external" "packer_ami_id" {
  depends_on = [null_resource.build_jenkins_ami]
  
  program = ["bash", "-c", <<-EOT
    cd ${path.module}/../../packer
    if [ -f manifest.json ]; then
      AMI_ID=$(jq -r '.builds[0].artifact_id' manifest.json | cut -d':' -f2)
      echo "{\"ami_id\":\"$AMI_ID\"}"
    else
      echo "{\"ami_id\":\"\"}"
      exit 1
    fi
  EOT
  ]
}

# Output AMI ID
output "packer_built_ami_id" {
  value       = data.external.packer_ami_id.result.ami_id
  description = "AMI ID built by Packer"
}
```

### 2. Update Packer Configuration to Accept EFS ID

Update `packer/jenkins-ami.pkr.hcl` or create `packer/variables.pkr.hcl`:

```hcl
variable "efs_id" {
  type        = string
  description = "EFS File System ID"
  default     = ""
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
  sensitive   = true
}
```

### 3. Update Packer to Use EFS ID in Provisioners

Add to `packer/jenkins-ami.pkr.hcl`:

```hcl
build {
  # ... existing configuration

  provisioner "file" {
    source      = "../playbooks/jenkins-setup.yml"
    destination = "/tmp/jenkins-setup.yml"
  }

  provisioner "file" {
    source      = "../playbooks/roles"
    destination = "/tmp/roles"
  }

  # Or use tar file approach
  provisioner "file" {
    source      = "jenkinsrole.tar"
    destination = "/home/ubuntu/jenkinsrole.tar"
  }

  provisioner "shell" {
    inline = [
      "cd /home/ubuntu",
      "tar -xvf jenkinsrole.tar",
      # Use EFS ID if provided
      "if [ -n '${var.efs_id}' ]; then echo 'EFS_ID=${var.efs_id}' >> /tmp/efs-config; fi"
    ]
  }
}
```

### 4. Create setup.sh Script (If Needed)

Create `packer/scripts/setup.sh`:

```bash
#!/bin/bash
set -e

EFS_ID=$1

if [ -z "$EFS_ID" ]; then
    echo "Error: EFS ID not provided"
    exit 1
fi

echo "Configuring for EFS: $EFS_ID"

# Extract and setup Ansible roles
cd /home/ubuntu
if [ -f jenkinsrole.tar ]; then
    tar -xvf jenkinsrole.tar
fi

# Configure EFS mount point (if needed during build)
# Note: EFS is typically mounted at runtime, not during AMI build
echo "EFS_ID=$EFS_ID" > /opt/jenkins/efs-id.txt

# Additional setup steps
# ...
```

### 5. Update Terraform Variables

Add to `terraform/main/variables.tf`:

```hcl
variable "aws_access_key" {
  type        = string
  description = "AWS Access Key for Packer build"
  sensitive   = true
  default     = ""
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key for Packer build"
  sensitive   = true
  default     = ""
}
```

### 6. Update ASG Module to Use Dynamic AMI

Update `terraform/main/main.tf`:

```hcl
module "asg" {
  source = "../modules/asg"

  # Use dynamically built AMI instead of var.jenkins_ami_id
  ami_id = data.external.packer_ami_id.result.ami_id != "" ? data.external.packer_ami_id.result.ami_id : var.jenkins_ami_id
  
  # ... rest of configuration
}
```

---

## GitLab CI/CD Flow Update

Based on the images, the GitLab CI/CD should follow this flow:

### Stage I: Checkout
- Clone repository
- Create `jenkinsrole.tar` from playbooks
- Prepare files

### Stage II: Terraform + Packer
1. **Terraform Init & Plan**
   - Initialize Terraform
   - Plan EFS creation

2. **Terraform Apply (EFS Only)**
   - Create EFS first
   - Get EFS ID

3. **Packer Build**
   - Terraform calls Packer with EFS ID
   - Packer builds AMI
   - Extract AMI ID

4. **Terraform Apply (Infrastructure)**
   - Use built AMI in ASG
   - Complete infrastructure deployment

### Stage III: Trivy Scan
- Scan the built AMI
- Generate security reports

---

## Implementation Checklist

- [ ] Create `terraform/main/packer-build.tf` with null_resource
- [ ] Add EFS ID variable to Packer configuration
- [ ] Create `jenkinsrole.tar` generation script
- [ ] Update Packer to accept and use EFS ID
- [ ] Create `setup.sh` script if needed
- [ ] Update Terraform to use dynamically built AMI
- [ ] Update GitLab CI/CD to follow new flow
- [ ] Test end-to-end flow

---

## Next Steps

1. **Review current structure** - Understand what exists
2. **Implement Terraform-Packer integration** - Add null_resource
3. **Update Packer configuration** - Accept EFS ID variable
4. **Update GitLab CI/CD** - Follow new flow
5. **Test the complete pipeline** - Verify end-to-end

---

**Note**: The current project structure separates Packer and Terraform. The images show an integrated approach where Terraform orchestrates the Packer build. This requires adding the `null_resource` pattern to call Packer from Terraform.

