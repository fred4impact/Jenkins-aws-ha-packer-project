#!/bin/sh
set -e

echo "Installing dependencies..."
apk add --no-cache python3 py3-pip curl unzip jq git

echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo "Installing Packer..."
wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
unzip packer_${PACKER_VERSION}_linux_amd64.zip
mv packer /usr/local/bin/
chmod +x /usr/local/bin/packer
packer version

echo "Installing Ansible..."
pip3 install --upgrade pip
pip3 install ansible
ansible --version

echo "Configuring AWS credentials..."
mkdir -p ~/.aws
echo "[default]" > ~/.aws/credentials
echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> ~/.aws/credentials
echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> ~/.aws/credentials
echo "[default]" > ~/.aws/config
echo "region = ${AWS_REGION}" >> ~/.aws/config




