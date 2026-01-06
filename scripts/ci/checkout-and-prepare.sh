#!/bin/sh
set -e

echo "=== STAGE I: CHECKOUT AND PREPARE ==="
echo "Repository: $CI_PROJECT_URL"
echo "Branch: $CI_COMMIT_REF_NAME"
echo "Commit: $CI_COMMIT_SHA"

echo "Verifying repository structure..."
ls -la
echo "Terraform directory:"
ls -la terraform/main/ || echo "Terraform directory not found"
echo "Packer directory:"
ls -la packer/ || echo "Packer directory not found"
echo "Playbooks directory:"
ls -la playbooks/ || echo "Playbooks directory not found"

echo "Creating jenkinsrole.tar (as per flow requirements)..."
cd ${PLAYBOOKS_ROOT}
if [ -f jenkins-setup.yml ] && [ -d roles ]; then
  tar -cvf jenkinsrole.tar jenkins-setup.yml roles ansible.cfg requirements.yml 2>/dev/null || true
  echo "✅ jenkinsrole.tar created"
  ls -lh jenkinsrole.tar
else
  echo "⚠️ Warning: jenkins-setup.yml or roles directory not found"
fi

echo "✅ Checkout and preparation completed"




