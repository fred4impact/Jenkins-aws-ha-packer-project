#!/bin/sh
set -e

echo "Installing AWS CLI..."
apk add --no-cache python3 py3-pip curl unzip ${EXTRA_PACKAGES:-}
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo "Configuring AWS credentials..."
mkdir -p ~/.aws
echo "[default]" > ~/.aws/credentials
echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> ~/.aws/credentials
echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> ~/.aws/credentials
echo "[default]" > ~/.aws/config
echo "region = ${AWS_REGION}" >> ~/.aws/config
echo "output = json" >> ~/.aws/config

if [ "${VERIFY_AWS:-true}" = "true" ]; then
  echo "Verifying AWS connection..."
  aws sts get-caller-identity
fi

