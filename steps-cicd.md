# Post-Deployment CI/CD and Operations Guide

This document provides step-by-step instructions for setting up CI/CD pipelines, monitoring, backups, and other operational tasks after successfully deploying the Jenkins HA infrastructure.

---

## Table of Contents

1. [Set Up CI/CD Pipelines in Jenkins](#1-set-up-cicd-pipelines-in-jenkins)
2. [Configure Backup Strategy for Jenkins Data](#2-configure-backup-strategy-for-jenkins-data)
3. [Set Up Monitoring and Alerting in CloudWatch](#3-set-up-monitoring-and-alerting-in-cloudwatch)
4. [Implement Disaster Recovery Procedures](#4-implement-disaster-recovery-procedures)
5. [Document Runbooks for Operations Team](#5-document-runbooks-for-operations-team)
6. [Set Up Automated AMI Updates via Jenkins Pipeline](#6-set-up-automated-ami-updates-via-jenkins-pipeline)
7. [Configure SSL/TLS Certificates for HTTPS](#7-configure-ssltls-certificates-for-https)
8. [Implement Blue-Green Deployments for AMI Updates](#8-implement-blue-green-deployments-for-ami-updates)

---

## 1. Set Up CI/CD Pipelines in Jenkins

### 1.1 Access Jenkins Web UI

```bash
# Get Jenkins URL from Terraform output
cd terraform/main
terraform output jenkins_url

# Or get ALB DNS name
terraform output alb_dns_name
```

1. Open browser and navigate to the Jenkins URL
2. Complete the initial setup wizard (if first time)
3. Install suggested plugins or select specific plugins

### 1.2 Install Required Jenkins Plugins

1. Go to **Manage Jenkins** → **Manage Plugins** → **Available**
2. Search and install the following plugins:
   - **Pipeline** (usually pre-installed)
   - **Git Plugin**
   - **GitHub Integration** (if using GitHub)
   - **Docker Pipeline**
   - **AWS Steps**
   - **Blue Ocean** (optional, for better UI)
   - **Credentials Binding**
   - **Ansible Plugin**
   - **Terraform Plugin**
   - **Kubernetes Plugin** (if deploying to K8s)

3. Click **Install without restart** or **Download now and install after restart**

### 1.3 Configure AWS Credentials in Jenkins

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click **System** → **Global credentials (unrestricted)**
3. Click **Add Credentials**
4. Configure:
   - **Kind**: AWS Credentials
   - **ID**: `aws-credentials`
   - **Access Key ID**: Your AWS Access Key
   - **Secret Access Key**: Your AWS Secret Key
   - **Description**: AWS credentials for CI/CD pipelines
5. Click **OK**

### 1.4 Configure GitHub/GitLab Credentials (if needed)

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Add credentials:
   - **Kind**: Username with password or SSH Username with private key
   - **ID**: `github-credentials` or `gitlab-credentials`
   - **Username**: Your Git username
   - **Password/Private Key**: Your Git token or SSH key
3. Click **OK**

### 1.5 Create Your First Pipeline

#### Option A: Create Pipeline from Jenkinsfile in Repository

1. Go to **New Item**
2. Enter item name: `my-app-pipeline`
3. Select **Pipeline**
4. Click **OK**
5. Configure:
   - **Pipeline Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your repository URL
   - **Credentials**: Select your Git credentials
   - **Branch**: `*/main` or your branch
   - **Script Path**: `Jenkinsfile` (or your pipeline file)
6. Click **Save**
7. Click **Build Now** to test

#### Option B: Create Declarative Pipeline

1. Go to **New Item** → **Pipeline**
2. Name: `sample-pipeline`
3. In **Pipeline** section, select **Pipeline script**
4. Enter pipeline script:

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        APP_NAME = 'my-application'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code...'
                git branch: 'main', url: 'https://github.com/your-org/your-repo.git'
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building application...'
                sh 'mvn clean package'  // or npm build, docker build, etc.
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests...'
                sh 'mvn test'  // or npm test, etc.
            }
        }
        
        stage('Deploy') {
            steps {
                echo 'Deploying application...'
                // Add deployment steps
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
```

5. Click **Save** and **Build Now**

### 1.6 Create Multi-Branch Pipeline (Recommended)

1. Go to **New Item**
2. Enter name: `my-app-multibranch`
3. Select **Multibranch Pipeline**
4. Configure:
   - **Branch Sources**: Add source (GitHub, GitLab, etc.)
   - **Repository URL**: Your repository
   - **Credentials**: Your Git credentials
   - **Behaviors**: Add behaviors as needed
5. Click **Save**
6. Jenkins will automatically discover branches with Jenkinsfiles

### 1.7 Example: CI/CD Pipeline for Application Deployment

Create a `Jenkinsfile` in your application repository:

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        ECR_REGISTRY = '123456789012.dkr.ecr.us-east-1.amazonaws.com'
        IMAGE_NAME = 'my-app'
        KUBERNETES_NAMESPACE = 'production'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    def imageTag = "${env.ECR_REGISTRY}/${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
                    sh """
                        docker build -t ${imageTag} .
                        docker tag ${imageTag} ${env.ECR_REGISTRY}/${env.IMAGE_NAME}:latest
                    """
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    sh """
                        aws ecr get-login-password --region ${env.AWS_REGION} | \
                        docker login --username AWS --password-stdin ${env.ECR_REGISTRY}
                        docker push ${env.ECR_REGISTRY}/${env.IMAGE_NAME}:${env.BUILD_NUMBER}
                        docker push ${env.ECR_REGISTRY}/${env.IMAGE_NAME}:latest
                    """
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                sh """
                    kubectl set image deployment/${env.IMAGE_NAME} \
                        ${env.IMAGE_NAME}=${env.ECR_REGISTRY}/${env.IMAGE_NAME}:${env.BUILD_NUMBER} \
                        -n ${env.KUBERNETES_NAMESPACE}
                """
            }
        }
    }
    
    post {
        success {
            echo "Deployment successful! Image: ${env.ECR_REGISTRY}/${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
        }
        failure {
            echo "Deployment failed!"
        }
    }
}
```

---

## 2. Configure Backup Strategy for Jenkins Data

### 2.1 Understand Jenkins Data Location

Jenkins data is stored on EFS at `/var/lib/jenkins` (mounted from EFS). This ensures all instances share the same data.

### 2.2 Create Backup Script

Create a backup script on one of the Jenkins instances:

```bash
#!/bin/bash
# /opt/jenkins/backup-jenkins.sh

set -e

BACKUP_DIR="/opt/jenkins/backups"
JENKINS_HOME="/var/lib/jenkins"
S3_BUCKET="your-jenkins-backups-bucket"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="jenkins-backup-${DATE}.tar.gz"

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Create backup
echo "Creating backup: ${BACKUP_FILE}"
tar -czf ${BACKUP_DIR}/${BACKUP_FILE} \
    --exclude='workspace' \
    --exclude='*.log' \
    ${JENKINS_HOME}

# Upload to S3
echo "Uploading to S3..."
aws s3 cp ${BACKUP_DIR}/${BACKUP_FILE} \
    s3://${S3_BUCKET}/jenkins-backups/${BACKUP_FILE}

# Keep only last 7 days of local backups
find ${BACKUP_DIR} -name "jenkins-backup-*.tar.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}"
```

### 2.3 Set Up Automated Backups with Cron

```bash
# SSH to Jenkins instance
ssh -i ~/.ssh/jenkins-ha-keypair.pem ubuntu@<instance-ip>

# Create backup script
sudo vi /opt/jenkins/backup-jenkins.sh
# Paste the script above and update S3_BUCKET

# Make executable
sudo chmod +x /opt/jenkins/backup-jenkins.sh

# Add to crontab (run daily at 2 AM)
sudo crontab -e
# Add this line:
0 2 * * * /opt/jenkins/backup-jenkins.sh >> /var/log/jenkins-backup.log 2>&1
```

### 2.4 Configure S3 Lifecycle Policy for Backups

```bash
# Create lifecycle policy JSON
cat > lifecycle-policy.json <<EOF
{
    "Rules": [
        {
            "Id": "JenkinsBackupLifecycle",
            "Status": "Enabled",
            "Prefix": "jenkins-backups/",
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "Days": 90,
                    "StorageClass": "GLACIER"
                }
            ],
            "Expiration": {
                "Days": 365
            }
        }
    ]
}
EOF

# Apply lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
    --bucket your-jenkins-backups-bucket \
    --lifecycle-configuration file://lifecycle-policy.json
```

### 2.5 Test Backup and Restore

#### Test Backup:
```bash
# Run backup manually
sudo /opt/jenkins/backup-jenkins.sh

# Verify backup in S3
aws s3 ls s3://your-jenkins-backups-bucket/jenkins-backups/
```

#### Test Restore:
```bash
# Download backup from S3
aws s3 cp s3://your-jenkins-backups-bucket/jenkins-backups/jenkins-backup-YYYYMMDD-HHMMSS.tar.gz /tmp/

# Extract backup (on a test instance)
sudo tar -xzf /tmp/jenkins-backup-YYYYMMDD-HHMMSS.tar.gz -C /tmp/restore-test

# Verify files
ls -la /tmp/restore-test/var/lib/jenkins/
```

### 2.6 Enable EFS Backup (AWS Backup)

```bash
# Create backup plan
aws backup create-backup-plan --backup-plan file://backup-plan.json

# backup-plan.json
cat > backup-plan.json <<EOF
{
    "BackupPlanName": "jenkins-efs-backup",
    "Rules": [
        {
            "RuleName": "DailyBackup",
            "TargetBackupVaultName": "Default",
            "ScheduleExpression": "cron(0 2 * * ? *)",
            "StartWindowMinutes": 60,
            "CompletionWindowMinutes": 120,
            "Lifecycle": {
                "DeleteAfterDays": 30
            }
        }
    ]
}
EOF

# Assign EFS to backup plan
aws backup create-backup-selection \
    --backup-plan-id <plan-id> \
    --backup-selection file://backup-selection.json
```

---

## 3. Set Up Monitoring and Alerting in CloudWatch

### 3.1 Enable CloudWatch Agent on Jenkins Instances

The CloudWatch agent should already be installed from the AMI. Verify and configure:

```bash
# SSH to Jenkins instance
ssh -i ~/.ssh/jenkins-ha-keypair.pem ubuntu@<instance-ip>

# Check if CloudWatch agent is installed
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -v

# Create CloudWatch agent configuration
sudo vi /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

CloudWatch agent configuration:

```json
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/jenkins/jenkins.log",
                        "log_group_name": "/aws/ec2/jenkins/jenkins.log",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/ec2/jenkins/system",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "Jenkins/HA",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"},
                    {"name": "cpu_usage_iowait", "rename": "CPU_IOWAIT", "unit": "Percent"},
                    {"name": "cpu_usage_user", "rename": "CPU_USER", "unit": "Percent"},
                    {"name": "cpu_usage_system", "rename": "CPU_SYSTEM", "unit": "Percent"}
                ],
                "totalcpu": false,
                "resources": ["*"]
            },
            "disk": {
                "measurement": [
                    {"name": "used_percent", "rename": "DISK_USED", "unit": "Percent"}
                ],
                "resources": ["*"]
            },
            "mem": {
                "measurement": [
                    {"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}
                ]
            }
        }
    }
}
```

Start CloudWatch agent:

```bash
# Start CloudWatch agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Verify agent is running
sudo systemctl status amazon-cloudwatch-agent
```

### 3.2 Create CloudWatch Alarms

#### Alarm 1: High CPU Utilization

```bash
aws cloudwatch put-metric-alarm \
    --alarm-name jenkins-high-cpu \
    --alarm-description "Alert when Jenkins CPU exceeds 80%" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:jenkins-alerts
```

#### Alarm 2: Jenkins Service Down

```bash
aws cloudwatch put-metric-alarm \
    --alarm-name jenkins-service-down \
    --alarm-description "Alert when Jenkins target is unhealthy" \
    --metric-name HealthyHostCount \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 60 \
    --threshold 1 \
    --comparison-operator LessThanThreshold \
    --evaluation-periods 1 \
    --dimensions Name=TargetGroup,Value=<target-group-arn> \
    --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:jenkins-alerts
```

#### Alarm 3: EFS Storage High

```bash
aws cloudwatch put-metric-alarm \
    --alarm-name jenkins-efs-storage-high \
    --alarm-description "Alert when EFS storage exceeds 80%" \
    --metric-name StorageBytes \
    --namespace AWS/EFS \
    --statistic Average \
    --period 300 \
    --threshold 858993459200 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=FileSystemId,Value=<efs-id> \
    --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:jenkins-alerts
```

### 3.3 Set Up SNS Topic for Alerts

```bash
# Create SNS topic
aws sns create-topic --name jenkins-alerts

# Subscribe email to topic
aws sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:jenkins-alerts \
    --protocol email \
    --notification-endpoint your-email@example.com

# Confirm subscription from email
```

### 3.4 Create CloudWatch Dashboard

```bash
# Create dashboard JSON
cat > jenkins-dashboard.json <<EOF
{
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["AWS/EC2", "CPUUtilization", {"stat": "Average"}],
                    [".", "NetworkIn", {"stat": "Sum"}],
                    [".", "NetworkOut", {"stat": "Sum"}]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Jenkins Instance Metrics"
            }
        },
        {
            "type": "log",
            "properties": {
                "query": "SOURCE '/aws/ec2/jenkins/jenkins.log' | fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
                "region": "us-east-1",
                "title": "Jenkins Error Logs"
            }
        }
    ]
}
EOF

# Create dashboard
aws cloudwatch put-dashboard \
    --dashboard-name Jenkins-HA-Dashboard \
    --dashboard-body file://jenkins-dashboard.json
```

### 3.5 View Metrics in CloudWatch Console

1. Go to AWS Console → CloudWatch
2. Navigate to **Dashboards** → **Jenkins-HA-Dashboard**
3. View real-time metrics and logs

---

## 4. Implement Disaster Recovery Procedures

### 4.1 Document Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO)

- **RTO**: Target recovery time (e.g., 1 hour)
- **RPO**: Maximum acceptable data loss (e.g., 24 hours)

### 4.2 Create Disaster Recovery Runbook

Create `DISASTER-RECOVERY-RUNBOOK.md`:

```markdown
# Jenkins HA Disaster Recovery Runbook

## Scenario 1: Single Instance Failure
- **Impact**: Minimal - other instances continue serving traffic
- **Action**: Auto Scaling Group automatically replaces failed instance
- **Time**: 5-10 minutes

## Scenario 2: EFS Failure
- **Impact**: All Jenkins instances lose access to shared data
- **Action**: 
  1. Restore EFS from backup
  2. Update EFS mount in instances
  3. Restart Jenkins service
- **Time**: 30-60 minutes

## Scenario 3: Complete Region Failure
- **Impact**: Complete service outage
- **Action**:
  1. Deploy infrastructure in secondary region
  2. Restore EFS from backup
  3. Update DNS to point to new region
- **Time**: 2-4 hours
```

### 4.3 Set Up Cross-Region Backup

```bash
# Enable cross-region replication for EFS backups
aws backup create-backup-vault \
    --backup-vault-name jenkins-backup-vault-dr \
    --region us-west-2

# Copy backups to secondary region
aws s3 sync s3://jenkins-backups-bucket-us-east-1 \
    s3://jenkins-backups-bucket-us-west-2 \
    --region us-west-2
```

### 4.4 Create DR Terraform Configuration

Create `terraform/dr/main.tf` for disaster recovery in secondary region:

```hcl
# Similar to main/main.tf but for DR region
provider "aws" {
  region = "us-west-2"  # Secondary region
  alias  = "dr"
}
```

### 4.5 Test Disaster Recovery

```bash
# Quarterly DR test procedure:
# 1. Document current state
# 2. Simulate failure scenario
# 3. Execute recovery procedure
# 4. Verify service restoration
# 5. Document lessons learned
```

---

## 5. Document Runbooks for Operations Team

### 5.1 Create Operations Runbook

Create `OPERATIONS-RUNBOOK.md`:

```markdown
# Jenkins HA Operations Runbook

## Daily Tasks
- [ ] Check CloudWatch dashboard for anomalies
- [ ] Review Jenkins build queue
- [ ] Verify backup completion

## Weekly Tasks
- [ ] Review and clean up old builds
- [ ] Check disk space on EFS
- [ ] Review security updates

## Monthly Tasks
- [ ] Review and update Jenkins plugins
- [ ] Test backup restore procedure
- [ ] Review and optimize costs
```

### 5.2 Common Operations Procedures

#### Restart Jenkins Service

```bash
# SSH to instance
ssh -i ~/.ssh/jenkins-ha-keypair.pem ec2-user@<instance-ip>

# Restart Jenkins
sudo systemctl restart jenkins

# Check status
sudo systemctl status jenkins
```

#### Clear Jenkins Build Queue

1. Access Jenkins UI
2. Go to **Manage Jenkins** → **Script Console**
3. Run:
```groovy
Jenkins.instance.queue.clear()
```

#### Add New Jenkins Plugin

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Search for plugin
3. Install and restart if needed

#### Scale Jenkins Instances

```bash
# Update Auto Scaling Group desired capacity
aws autoscaling set-desired-capacity \
    --auto-scaling-group-name ha-jenkins-asg \
    --desired-capacity 3 \
    --honor-cooldown
```

---

## 6. Set Up Automated AMI Updates via Jenkins Pipeline

### 6.1 Create Jenkins Pipeline for AMI Builds

Create a new Jenkins pipeline job:

1. Go to **New Item** → **Pipeline**
2. Name: `build-jenkins-ami`
3. Configure pipeline:

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        PACKER_DIR = 'packer'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build AMI with Packer') {
            steps {
                dir('packer') {
                    sh '''
                        packer init .
                        packer validate .
                        packer build .
                    '''
                }
            }
        }
        
        stage('Extract AMI ID') {
            steps {
                script {
                    def manifest = readJSON file: 'packer/manifest.json'
                    env.AMI_ID = manifest.builds[0].artifact_id.split(':')[1]
                    echo "Built AMI: ${env.AMI_ID}"
                }
            }
        }
        
        stage('Scan AMI with Trivy') {
            steps {
                sh '''
                    docker pull aquasec/trivy:latest
                    docker run --rm \
                        -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
                        -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
                        -e AWS_DEFAULT_REGION=${AWS_REGION} \
                        aquasec/trivy image --exit-code 0 --severity HIGH,CRITICAL ${AMI_ID}
                '''
            }
        }
        
        stage('Update Terraform with New AMI') {
            steps {
                script {
                    sh """
                        cd terraform/main
                        sed -i.bak 's/jenkins_ami_id = ".*"/jenkins_ami_id = "${env.AMI_ID}"/' terraform.tfvars
                    """
                }
            }
        }
        
        stage('Plan Infrastructure Update') {
            steps {
                dir('terraform/main') {
                    sh '''
                        terraform init
                        terraform plan -out=tfplan
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo "AMI build successful: ${env.AMI_ID}"
            // Optionally trigger infrastructure update
        }
        failure {
            echo "AMI build failed!"
        }
    }
}
```

### 6.2 Schedule Automated AMI Builds

1. In pipeline configuration, enable **Build Triggers**
2. Select **Build periodically**
3. Enter schedule: `H 2 * * 0` (Every Sunday at 2 AM)
4. Save

### 6.3 Create Pipeline for Infrastructure Updates

Create another pipeline: `update-jenkins-infrastructure`

```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'AMI_ID', defaultValue: '', description: 'AMI ID to deploy')
    }
    
    stages {
        stage('Update Terraform') {
            steps {
                dir('terraform/main') {
                    sh """
                        sed -i.bak 's/jenkins_ami_id = ".*"/jenkins_ami_id = "${params.AMI_ID}"/' terraform.tfvars
                    """
                }
            }
        }
        
        stage('Apply Terraform') {
            steps {
                dir('terraform/main') {
                    sh '''
                        terraform init
                        terraform plan -out=tfplan
                        terraform apply tfplan
                    '''
                }
            }
        }
    }
}
```

---

## 7. Configure SSL/TLS Certificates for HTTPS

### 7.1 Request ACM Certificate

```bash
# Request certificate via DNS validation
aws acm request-certificate \
    --domain-name jenkins.yourdomain.com \
    --validation-method DNS \
    --region us-east-1

# Get validation records
aws acm describe-certificate \
    --certificate-arn <certificate-arn> \
    --region us-east-1
```

### 7.2 Add DNS Validation Records

1. Go to your DNS provider (Route 53, etc.)
2. Add CNAME records from ACM validation
3. Wait for certificate validation (usually 5-30 minutes)

### 7.3 Update Terraform to Use HTTPS

Update `terraform/main/main.tf`:

```hcl
# Update ELB module to use HTTPS
module "elb" {
  source = "../modules/elb"
  
  # ... existing configuration ...
  
  certificate_arn = var.acm_certificate_arn  # Add this
  enable_https    = true                      # Add this
}
```

Update `terraform/main/variables.tf`:

```hcl
variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS"
}
```

Update `terraform/main/terraform.tfvars`:

```hcl
acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID"
```

### 7.4 Apply Terraform Changes

```bash
cd terraform/main
terraform init
terraform plan
terraform apply
```

### 7.5 Update DNS to Point to ALB

```bash
# Get ALB DNS name
terraform output alb_dns_name

# Update Route 53 record (if using Route 53)
aws route53 change-resource-record-sets \
    --hosted-zone-id Z1234567890ABC \
    --change-batch file://route53-change.json
```

### 7.6 Verify HTTPS

```bash
# Test HTTPS endpoint
curl -I https://jenkins.yourdomain.com

# Should return 200 OK or redirect to login
```

---

## 8. Implement Blue-Green Deployments for AMI Updates

### 8.1 Create Blue-Green Deployment Script

Create `scripts/blue-green-deploy.sh`:

```bash
#!/bin/bash
set -e

AMI_ID=$1
ENVIRONMENT=${2:-production}

if [ -z "$AMI_ID" ]; then
    echo "Usage: $0 <ami-id> [environment]"
    exit 1
fi

echo "Starting blue-green deployment with AMI: $AMI_ID"

# Step 1: Create Green Auto Scaling Group
echo "Creating green ASG..."
cd terraform/main
terraform workspace new green-${AMI_ID} || terraform workspace select green-${AMI_ID}

# Update terraform.tfvars with new AMI
sed -i.bak "s/jenkins_ami_id = \".*\"/jenkins_ami_id = \"${AMI_ID}\"/" terraform.tfvars

# Apply green infrastructure
terraform init
terraform plan -out=green-plan
terraform apply green-plan

# Step 2: Wait for Green instances to be healthy
echo "Waiting for green instances to be healthy..."
GREEN_TG_ARN=$(terraform output -raw green_target_group_arn)
aws elbv2 wait target-in-service \
    --target-group-arn ${GREEN_TG_ARN} \
    --targets Id=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names green-jenkins-asg \
        --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
        --output text)

# Step 3: Switch traffic to Green
echo "Switching traffic to green environment..."
aws elbv2 modify-listener \
    --listener-arn $(terraform output -raw alb_listener_arn) \
    --default-actions Type=forward,TargetGroupArn=${GREEN_TG_ARN}

# Step 4: Monitor Green for 30 minutes
echo "Monitoring green environment for 30 minutes..."
sleep 1800

# Step 5: Destroy Blue (old) environment
echo "Destroying blue environment..."
terraform workspace select default
terraform destroy -auto-approve

# Step 6: Rename Green to Blue
echo "Renaming green to blue..."
terraform workspace select green-${AMI_ID}
terraform state mv module.asg.aws_autoscaling_group.jenkins module.asg.aws_autoscaling_group.jenkins-blue

echo "Blue-green deployment completed successfully!"
```

### 8.2 Create Jenkins Pipeline for Blue-Green Deployment

Add to your AMI update pipeline:

```groovy
stage('Blue-Green Deployment') {
    steps {
        script {
            sh """
                chmod +x scripts/blue-green-deploy.sh
                ./scripts/blue-green-deploy.sh ${env.AMI_ID}
            """
        }
    }
}
```

### 8.3 Manual Blue-Green Deployment Steps

```bash
# 1. Build new AMI
cd packer
packer build .
# Note the AMI ID

# 2. Create green environment
cd ../terraform/main
terraform workspace new green
# Update terraform.tfvars with new AMI ID
terraform apply

# 3. Test green environment
# Access green ALB and verify functionality

# 4. Switch traffic
# Update ALB listener to point to green target group

# 5. Monitor
# Watch CloudWatch metrics and logs

# 6. Complete deployment
# If successful, destroy blue environment
terraform workspace select default
terraform destroy

# If failed, rollback
# Switch traffic back to blue
# Destroy green environment
```

### 8.4 Rollback Procedure

```bash
# If deployment fails, rollback:
# 1. Switch ALB back to blue target group
aws elbv2 modify-listener \
    --listener-arn <listener-arn> \
    --default-actions Type=forward,TargetGroupArn=<blue-tg-arn>

# 2. Destroy green environment
terraform workspace select green
terraform destroy

# 3. Document failure and root cause
```

---

## Additional Best Practices

### Security Hardening

1. **Regular Security Updates**:
   ```bash
   # Schedule weekly security updates
   sudo apt-get update && sudo apt-get upgrade --security -y
   ```

2. **Rotate Credentials**:
   - Rotate AWS credentials every 90 days
   - Rotate Jenkins admin password regularly
   - Use AWS Secrets Manager for sensitive data

3. **Enable MFA**:
   - Enable MFA for Jenkins admin users
   - Use OAuth/SAML for authentication

### Cost Optimization

1. **Right-Size Instances**:
   ```bash
   # Monitor instance utilization
   aws cloudwatch get-metric-statistics \
       --namespace AWS/EC2 \
       --metric-name CPUUtilization \
       --dimensions Name=AutoScalingGroupName,Value=ha-jenkins-asg \
       --start-time 2024-01-01T00:00:00Z \
       --end-time 2024-01-31T23:59:59Z \
       --period 3600 \
       --statistics Average
   ```

2. **Use Spot Instances** (for non-production):
   ```hcl
   # Add spot instance configuration to launch template
   instance_market_options {
     market_type = "spot"
     spot_options {
       max_price = "0.10"
     }
   }
   ```

3. **Clean Up Old Resources**:
   - Delete old AMIs and snapshots
   - Archive old Jenkins builds
   - Clean up unused EBS volumes

### Performance Tuning

1. **Jenkins Configuration**:
   - Tune JVM heap size in `/etc/sysconfig/jenkins`
   - Configure number of executors
   - Enable build caching

2. **EFS Performance**:
   - Use EFS Provisioned Throughput for better performance
   - Enable EFS Lifecycle Management

---

## Troubleshooting

### Common Issues

1. **Jenkins Not Accessible**:
   - Check ALB health checks
   - Verify security groups
   - Check instance logs

2. **High CPU/Memory**:
   - Review running builds
   - Check for stuck jobs
   - Scale up instances

3. **EFS Mount Issues**:
   - Verify EFS security group
   - Check IAM permissions
   - Verify mount targets

---

## Summary Checklist

After completing all steps, verify:

- [ ] CI/CD pipelines are working
- [ ] Backups are running and tested
- [ ] CloudWatch monitoring is active
- [ ] Alerts are configured and tested
- [ ] Disaster recovery plan is documented
- [ ] Operations runbook is complete
- [ ] Automated AMI updates are scheduled
- [ ] HTTPS is configured and working
- [ ] Blue-green deployment process is tested

---

**Last Updated:** $(date)
**Version:** 1.0.0

