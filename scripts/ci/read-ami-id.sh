#!/bin/sh
set -e

echo "Reading AMI ID from previous stage..."
if [ -f terraform/main/ami-id.txt ]; then
  source terraform/main/ami-id.txt
  echo "AMI ID: ${AMI_ID}"
else
  echo "❌ Error: ami-id.txt not found"
  exit 1
fi

if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "" ]; then
  echo "❌ Error: AMI_ID is empty"
  exit 1
fi

echo "Verifying AMI exists in AWS..."
aws ec2 describe-images \
  --image-ids ${AMI_ID} \
  --region ${AWS_REGION} \
  --query 'Images[0].[ImageId,Name,State]' \
  --output table



