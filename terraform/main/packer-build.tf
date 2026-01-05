# Packer Build Resource
# This resource calls Packer to build the AMI after EFS is created
# It follows the flow: Create EFS → Build AMI with EFS ID → Use AMI in ASG

resource "null_resource" "build_jenkins_ami" {
  depends_on = [module.efs]

  triggers = {
    # Rebuild AMI if any of these change
    efs_id         = module.efs.efs_id
    packer_config  = filemd5("${path.module}/../../packer/jenkins-ami.pkr.hcl")
    install_script = filemd5("${path.module}/../../packer/scripts/install-jenkins.sh")
    jenkins_config = filemd5("${path.module}/../../jenkins-config/jenkins-ha-config.xml")
    playbook       = filemd5("${path.module}/../../playbooks/jenkins-setup.yml")
    variables      = filemd5("${path.module}/../../packer/variables.pkr.hcl")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "=== Building Jenkins AMI with Packer ==="
      echo "EFS ID: ${module.efs.efs_id}"
      echo "Region: ${var.aws_region}"
      
      cd ${path.module}/../../packer
      
      # Create jenkinsrole.tar if it doesn't exist (as shown in images)
      if [ ! -f jenkinsrole.tar ] || [ ! -s jenkinsrole.tar ]; then
        echo "Creating jenkinsrole.tar from playbooks..."
        tar -cvf jenkinsrole.tar \
          ../playbooks/jenkins-setup.yml \
          ../playbooks/roles \
          ../playbooks/ansible.cfg \
          ../playbooks/requirements.yml 2>/dev/null || true
        echo "✅ jenkinsrole.tar created"
      else
        echo "✅ jenkinsrole.tar already exists"
      fi
      
      # Initialize Packer plugins
      echo "Initializing Packer plugins..."
      packer init . || echo "Packer init completed (plugins may already be installed)"
      
      # Validate Packer configuration
      echo "Validating Packer configuration..."
      packer validate \
        -var "efs_id=${module.efs.efs_id}" \
        -var "aws_region=${var.aws_region}" \
        -var "jenkins_version=${var.jenkins_version}" \
        -var "java_version=${var.java_version}" \
        -var "aws_access_key=${var.aws_access_key}" \
        -var "aws_secret_key=${var.aws_secret_key}" \
        . || {
          echo "❌ Packer validation failed"
          exit 1
        }
      
      # Build AMI with Packer
      echo "Building AMI with Packer..."
      packer build \
        -var "efs_id=${module.efs.efs_id}" \
        -var "aws_region=${var.aws_region}" \
        -var "jenkins_version=${var.jenkins_version}" \
        -var "java_version=${var.java_version}" \
        -var "aws_access_key=${var.aws_access_key}" \
        -var "aws_secret_key=${var.aws_secret_key}" \
        -machine-readable \
        . | tee packer-build.log
      
      # Verify manifest.json was created
      if [ ! -f manifest.json ]; then
        echo "❌ Error: manifest.json not found after build"
        exit 1
      fi
      
      echo "✅ AMI build completed successfully"
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
      if [ -n "$AMI_ID" ] && [ "$AMI_ID" != "null" ]; then
        echo "{\"ami_id\":\"$AMI_ID\"}"
      else
        echo "{\"ami_id\":\"\"}"
        exit 1
      fi
    else
      echo "{\"ami_id\":\"\"}"
      exit 1
    fi
  EOT
  ]
}

# Output the built AMI ID
output "packer_built_ami_id" {
  value       = data.external.packer_ami_id.result.ami_id
  description = "AMI ID built by Packer (configured with EFS)"

  depends_on = [null_resource.build_jenkins_ami, data.external.packer_ami_id]
}

