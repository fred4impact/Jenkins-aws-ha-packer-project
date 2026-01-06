# HCP Packer Registry Integration Guide

This guide explains how to integrate your Packer builds with HCP Packer (HashiCorp Cloud Platform Packer) registry for centralized AMI management and versioning.

## What is HCP Packer?

HCP Packer is a service that provides:
- **Centralized AMI Registry**: Track and manage all your AMIs in one place
- **Versioning**: Automatic version tracking of your AMIs
- **Channel Management**: Use channels (like `production`, `staging`) to manage AMI versions
- **Metadata**: Store metadata about your AMIs (build info, tags, etc.)
- **Integration**: Easy integration with Terraform to use the latest AMI versions

---

## Prerequisites

1. **HashiCorp Cloud Platform Account**
   - Sign up at: https://portal.cloud.hashicorp.com/
   - Free tier available

2. **HCP Organization and Project**
   - Create an organization (if you don't have one)
   - Create a project for your Packer builds

3. **Service Principal (for CI/CD)**
   - Create a service principal for GitHub Actions authentication
   - Or use user token for local testing

---

## Step-by-Step Integration

### **Step 1: Set Up HCP Packer Registry**

1. **Log in to HCP Portal**
   - Go to: https://portal.cloud.hashicorp.com/
   - Navigate to **Packer** in the left sidebar

2. **Create a Bucket**
   - Click **"Create Bucket"**
   - Name: `jenkins-ha-ami` (or your preferred name)
   - Description: "Jenkins HA AMI builds"
   - Click **"Create Bucket"**

3. **Create Channels** (Optional but Recommended)
   - **Production Channel**: For production-ready AMIs
   - **Staging Channel**: For testing AMIs
   - **Development Channel**: For development builds
   
   To create a channel:
   - Go to your bucket
   - Click **"Channels"** tab
   - Click **"Create Channel"**
   - Name: `production` (or `staging`, `dev`)
   - Click **"Create"**

---

### **Step 2: Get HCP Credentials**

#### **Option A: Service Principal (Recommended for CI/CD)**

1. **Create Service Principal**
   - Go to **Access Control (IAM)** → **Service Principals**
   - Click **"Create Service Principal"**
   - Name: `github-actions-packer`
   - Description: "Service principal for GitHub Actions Packer builds"
   - Click **"Create"**

2. **Create API Key**
   - Click on the service principal
   - Go to **"API Keys"** tab
   - Click **"Generate API Key"**
   - **Save the Client ID and Client Secret** (you'll need these for GitHub Secrets)

3. **Grant Permissions**
   - Assign the service principal to your project
   - Grant `Packer Writer` role (or appropriate permissions)

#### **Option B: User Token (For Local Testing)**

1. **Generate User Token**
   - Go to **User Settings** → **Access Tokens**
   - Click **"Generate Token"**
   - Name: `packer-local-dev`
   - Copy the token (you'll need this)

---

### **Step 3: Update Packer Configuration**

You'll need to add the HCP Packer configuration to your `packer/jenkins-ami.pkr.hcl` file:

#### **3.1 Add HCP Packer Plugin**

Add to the `packer` block (already exists, just add the hcp plugin):

```hcl
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
    hcp = {
      source  = "github.com/hashicorp/hcp"
      version = "~> 1"
    }
  }
}
```

#### **3.2 Add HCP Packer Configuration Block**

Add this block after your `build` block (before the closing brace):

```hcl
build {
  # ... existing build configuration ...

  # HCP Packer Registry Configuration
  hcp_packer_registry {
    bucket_name = "jenkins-ha-ami"
    description  = "Jenkins HA AMI built with Packer"
    
    bucket_labels = {
      "project"     = "jenkins-ha"
      "environment" = "production"
      "managed-by"  = "packer"
    }
    
    build_labels = {
      "jenkins-version" = var.jenkins_version
      "java-version"    = var.java_version
      "build-date"      = timestamp()
      "git-commit"      = "${env.GITHUB_SHA}"  # If using GitHub Actions
    }
  }
}
```

#### **3.3 Add Channel Assignment (Optional)**

To automatically assign builds to channels, add this to your build block:

```hcl
build {
  # ... existing configuration ...

  # Assign to channel based on environment
  hcp_packer_registry {
    # ... existing hcp_packer_registry config ...
  }
  
  # Post-processor to assign to channel
  post-processor "hcp" {
    bucket_name = "jenkins-ha-ami"
    channel_name = "production"  # or use variable: var.environment
  }
}
```

---

### **Step 4: Configure Authentication**

#### **For Local Development:**

1. **Set Environment Variables**
   ```bash
   export HCP_CLIENT_ID="your-client-id"
   export HCP_CLIENT_SECRET="your-client-secret"
   ```

   Or use HCP CLI:
   ```bash
   hcp auth login
   ```

#### **For GitHub Actions:**

1. **Add GitHub Secrets**
   - Go to your repository → **Settings** → **Secrets and variables** → **Actions**
   - Add the following secrets:
     - `HCP_CLIENT_ID`: Your service principal Client ID
     - `HCP_CLIENT_SECRET`: Your service principal Client Secret
     - `HCP_ORGANIZATION_ID`: Your HCP organization ID
     - `HCP_PROJECT_ID`: Your HCP project ID

2. **Update GitHub Actions Workflow**

   Add these steps before the Packer build:

   ```yaml
   - name: Configure HCP Packer credentials
     env:
       HCP_CLIENT_ID: ${{ secrets.HCP_CLIENT_ID }}
       HCP_CLIENT_SECRET: ${{ secrets.HCP_CLIENT_SECRET }}
     run: |
       echo "HCP credentials configured"
   ```

   The Packer build step will automatically use these environment variables.

---

### **Step 5: Initialize and Build**

1. **Initialize Packer Plugins**
   ```bash
   cd packer
   packer init .
   ```
   This will download the HCP Packer plugin.

2. **Build with HCP Integration**
   ```bash
   packer build \
     -var "aws_region=us-east-1" \
     -var "jenkins_version=2.414.3" \
     -var "java_version=17" \
     .
   ```

3. **Verify in HCP Portal**
   - Go to HCP Portal → Packer
   - Navigate to your bucket
   - You should see your build with version information

---

### **Step 6: Use HCP Packer in Terraform**

Once your AMIs are in HCP Packer, you can reference them in Terraform:

#### **6.1 Add HCP Provider**

In your `terraform/main/main.tf`:

```hcl
terraform {
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.79"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "hcp" {
  # Authentication via environment variables or credentials file
}
```

#### **6.2 Get AMI from HCP Packer**

```hcl
data "hcp_packer_image" "jenkins_ami" {
  bucket_name    = "jenkins-ha-ami"
  channel_name   = "production"  # or "staging", "dev"
  cloud_provider = "aws"
  region         = "us-east-1"
}

# Use in your launch template
resource "aws_launch_template" "jenkins" {
  # ... other configuration ...
  
  image_id = data.hcp_packer_image.jenkins_ami.cloud_image_id
  
  # ... rest of configuration ...
}
```

#### **6.3 Update Terraform Variables**

You can remove the `jenkins_ami_id` variable from Terraform since it will come from HCP Packer:

```hcl
# Remove or make optional:
variable "jenkins_ami_id" {
  type        = string
  description = "AMI ID (now sourced from HCP Packer)"
  default     = ""  # Will use HCP Packer if empty
}
```

---

## Workflow Integration

### **Updated Workflow with HCP Packer**

Your GitHub Actions workflow will now:

1. **Build AMI** → Packer builds and pushes to HCP Packer registry
2. **Scan AMI** → Trivy scans the AMI (unchanged)
3. **Assign to Channel** → AMI assigned to appropriate channel (production/staging)
4. **Deploy Infrastructure** → Terraform pulls AMI from HCP Packer channel

### **Channel Strategy**

Recommended channel workflow:

```
Build → Development Channel → Testing → Staging Channel → Production Channel
```

- **Development**: Latest builds (auto-assigned)
- **Staging**: Tested builds (manual promotion)
- **Production**: Production-ready builds (manual promotion)

---

## Benefits of HCP Packer Integration

1. **Centralized Management**
   - All AMIs in one place
   - Easy to see what's deployed where

2. **Version Control**
   - Automatic versioning
   - Track which AMI version is in production

3. **Channel Management**
   - Promote AMIs through environments
   - Rollback to previous versions easily

4. **Terraform Integration**
   - No hardcoded AMI IDs
   - Always use the latest from a channel
   - Easy to update across all environments

5. **Metadata Tracking**
   - Build information
   - Git commit SHA
   - Build date
   - Custom labels

---

## Troubleshooting

### **Issue: Authentication Failed**

**Solution:**
- Verify `HCP_CLIENT_ID` and `HCP_CLIENT_SECRET` are correct
- Check service principal has proper permissions
- Ensure you're using the correct organization/project IDs

### **Issue: Bucket Not Found**

**Solution:**
- Verify bucket name matches exactly (case-sensitive)
- Check you're in the correct HCP project
- Ensure bucket exists in HCP Portal

### **Issue: Plugin Not Found**

**Solution:**
- Run `packer init .` to download plugins
- Check plugin version compatibility
- Verify network access to download plugins

### **Issue: Build Succeeds but Not in HCP**

**Solution:**
- Check HCP credentials are set correctly
- Verify bucket name is correct
- Check build logs for HCP-related errors
- Ensure service principal has `Packer Writer` role

---

## Best Practices

1. **Use Channels for Environments**
   - `production` for production
   - `staging` for staging
   - `dev` for development

2. **Tag Your Builds**
   - Use build labels for metadata
   - Include Git commit SHA
   - Add build date and version info

3. **Promote Through Channels**
   - Don't assign directly to production
   - Test in staging first
   - Promote manually after validation

4. **Monitor HCP Usage**
   - Check HCP Portal regularly
   - Monitor for failed builds
   - Review channel assignments

5. **Backup Strategy**
   - HCP Packer stores metadata, not AMIs
   - AMIs are still in AWS
   - Consider AMI lifecycle policies

---

## Cost Considerations

- **HCP Packer**: Free tier available (limited builds per month)
- **AWS AMIs**: Standard AWS storage costs apply
- **No additional charges** for using HCP Packer with AWS

---

## Next Steps

1. ✅ Set up HCP account and create bucket
2. ✅ Create service principal for GitHub Actions
3. ✅ Add HCP Packer configuration to `packer/jenkins-ami.pkr.hcl`
4. ✅ Add HCP secrets to GitHub repository
5. ✅ Update GitHub Actions workflow (add HCP credentials)
6. ✅ Test build locally first
7. ✅ Update Terraform to use HCP Packer data source
8. ✅ Set up channels for different environments

---

## Additional Resources

- [HCP Packer Documentation](https://developer.hashicorp.com/packer/docs/hcp)
- [HCP Packer Terraform Provider](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs)
- [HCP Packer Best Practices](https://developer.hashicorp.com/packer/docs/hcp/best-practices)
- [HCP Portal](https://portal.cloud.hashicorp.com/)

---

## Summary

Integrating HCP Packer provides:
- ✅ Centralized AMI registry
- ✅ Automatic versioning
- ✅ Channel management
- ✅ Easy Terraform integration
- ✅ Better tracking and visibility

The integration requires:
1. HCP account setup
2. Packer configuration update
3. Authentication setup
4. Terraform provider configuration

All without changing your core build process!


