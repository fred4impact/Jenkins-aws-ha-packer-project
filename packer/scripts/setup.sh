#!/bin/bash
# setup.sh - Setup script for Jenkins AMI build
# This script is called by Packer with EFS ID as parameter (as shown in images)
# Usage: ./setup.sh <efs_id>

set -e

EFS_ID=$1

echo "=========================================="
echo "Jenkins AMI Setup Script"
echo "=========================================="

if [ -n "$EFS_ID" ]; then
    echo "EFS ID provided: $EFS_ID"
    # Store EFS ID for use during instance launch
    echo "EFS_ID=$EFS_ID" | sudo tee /opt/jenkins/efs-id.txt
    echo "✅ EFS ID stored in /opt/jenkins/efs-id.txt"
else
    echo "⚠️  Warning: No EFS ID provided"
    echo "EFS will need to be configured during instance launch"
fi

# Extract jenkinsrole.tar if it exists
if [ -f /home/ubuntu/jenkinsrole.tar ]; then
    echo "Extracting jenkinsrole.tar..."
    cd /home/ubuntu
    tar -xvf jenkinsrole.tar
    echo "✅ jenkinsrole.tar extracted"
    
    # Set proper permissions
    if [ -d roles ]; then
        sudo chown -R ubuntu:ubuntu roles
        echo "✅ Permissions set for roles directory"
    fi
fi

# Additional setup tasks can be added here
# For example:
# - Install additional packages
# - Configure system settings
# - Prepare Ansible roles for later use

echo "=========================================="
echo "Setup completed successfully"
echo "=========================================="

