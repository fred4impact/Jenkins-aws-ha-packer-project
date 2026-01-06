# Complete DevOps Workflow: Step-by-Step Guide

This document explains the complete workflow for building and deploying a High Availability Jenkins infrastructure on AWS, using multiple DevOps tools in a coordinated process.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    JENKINS PIPELINE                          │
│              (Orchestrates the entire process)               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STEP 1: Packer for Building AMI      │
        │  STEP 2: Ansible for Configuring      │
        │  STEP 3: Trivy for Scanning           │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  STEP 4: Terraform for Infrastructure │
        │  STEP 5: Shell Scripts for Automation │
        └───────────────────────────────────────┘
```

## Tool Stack and Responsibilities

| Tool | Purpose | Stage |
|------|---------|-------|
| **Jenkins Pipeline** | Orchestrates and automates the entire workflow | Orchestration |
| **Packer** | Builds Golden AMI from base image | AMI Creation |
| **Ansible** | Configures Jenkins Master and applies OS updates | Configuration |
| **Trivy** | Scans AMI for security vulnerabilities | Security |
| **Terraform** | Creates infrastructure (network, ASG, template, EFS, ELB) | Infrastructure |
| **Shell Scripts** | Automates various tasks and post-deployment setup | Automation |

---

## Detailed Step-by-Step Workflow

### **STEP 1: Packer for Building AMI**

**Purpose**: Create a standardized, pre-configured Amazon Machine Image (AMI) that contains Jenkins and all required dependencies.

**What Packer Does**:
- Takes a base AMI (e.g., Amazon Linux 2, Ubuntu)
- Launches a temporary EC2 instance
- Installs and configures software on the instance
- Creates a snapshot (Golden AMI) of the configured instance
- Terminates the temporary instance

**Process**:
```bash
Base AMI → Temporary EC2 → Install Software → Create Snapshot → Golden AMI
```

**Key Actions**:
1. **Initialize Packer**: `packer init .`
2. **Validate Configuration**: `packer validate jenkins-ami.pkr.hcl`
3. **Build AMI**: `packer build jenkins-ami.pkr.hcl`
4. **Output**: AMI ID (e.g., `ami-0abc123def456789`)

**Configuration File**: `packer/jenkins-ami.pkr.hcl`

**What Gets Installed**:
- Operating system updates
- Java (JDK/JRE)
- Jenkins (specific version)
- Docker
- AWS CLI
- EFS utilities
- CloudWatch agent
- Other organization-specific tools

**Output**: Golden AMI ID ready for use in Auto Scaling Groups

---

### **STEP 2: Ansible for Configuring Jenkins Master and OS Updates**

**Purpose**: Apply organization-specific configurations, security settings, and OS updates to the Jenkins Master instance.

**What Ansible Does**:
- Connects to the temporary EC2 instance (during Packer build)
- Executes playbooks to configure the system
- Applies security hardening
- Installs and configures Jenkins plugins
- Sets up system-level configurations

**Process**:
```bash
Ansible Playbook → Connect to Instance → Apply Configurations → Verify
```

**Key Actions**:
1. **Playbook Execution**: Runs during Packer build phase
2. **OS Updates**: `yum update` or `apt update`
3. **Jenkins Configuration**: 
   - Configure Jenkins settings
   - Install required plugins
   - Set up security policies
   - Configure system properties
4. **Security Hardening**:
   - Apply CIS benchmarks
   - Configure firewall rules
   - Set up audit logging
   - Install security agents

**Configuration Files**:
- `playbooks/jenkins-setup.yml` - Main Ansible playbook
- `playbooks/roles/jenkins/` - Jenkins-specific roles
- `playbooks/roles/security/` - Security hardening roles

**Example Playbook Structure**:
```yaml
---
- name: Configure Jenkins Master
  hosts: localhost
  become: yes
  tasks:
    - name: Update OS packages
      yum:
        name: "*"
        state: latest
    
    - name: Install Jenkins plugins
      jenkins_plugin:
        name: "{{ item }}"
        jenkins_home: /var/lib/jenkins
      loop:
        - pipeline
        - docker
        - aws-credentials
    
    - name: Configure Jenkins security
      template:
        src: jenkins-security.xml.j2
        dest: /var/lib/jenkins/config.xml
```

**Output**: Fully configured Jenkins Master in the AMI

---

### **STEP 3: Trivy for Scanning Vulnerabilities**

**Purpose**: Security scanning of the Golden AMI to identify vulnerabilities before it's used in production.

**What Trivy Does**:
- Scans the AMI for known security vulnerabilities
- Checks for outdated packages with CVEs
- Identifies misconfigurations
- Generates security reports
- Can fail the build if critical issues are found

**Process**:
```bash
Golden AMI → Trivy Scanner → Vulnerability Report → Pass/Fail Decision
```

**Key Actions**:
1. **Pull Trivy Image**: `docker pull aquasec/trivy:latest`
2. **Scan AMI**: `trivy image <ami-id>`
3. **Generate Reports**: JSON and HTML formats
4. **Check Severity**: Fail on CRITICAL, warn on HIGH
5. **Store Reports**: Upload to S3 or artifact storage

**Scan Command**:
```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION=us-east-1 \
  aquasec/trivy image \
  --format json \
  --output trivy-report.json \
  --severity HIGH,CRITICAL \
  ami-0abc123def456789
```

**What Gets Scanned**:
- Operating system packages
- Application dependencies
- Configuration files
- Security misconfigurations

**Output**: 
- Security scan report (JSON/HTML)
- List of vulnerabilities by severity
- Pass/Fail status for pipeline

**Integration**: Runs automatically in Jenkins pipeline after AMI build

---

### **STEP 4: Terraform for Infrastructure Creation**

**Purpose**: Provision and manage the complete AWS infrastructure required for High Availability Jenkins.

**What Terraform Creates**:

#### **4.1 Network Infrastructure**
- **VPC**: Virtual Private Cloud with custom CIDR
- **Subnets**: Public and private subnets across multiple AZs
- **Internet Gateway**: For public internet access
- **NAT Gateways**: For outbound internet from private subnets
- **Route Tables**: For network routing
- **Security Groups**: Network-level firewall rules

#### **4.2 Auto Scaling Group (ASG)**
- **Launch Template**: Defines EC2 instance configuration
  - Uses the Golden AMI from Step 1
  - Instance type, key pairs, security groups
  - User data scripts
- **Auto Scaling Group**: Manages Jenkins instances
  - Min/Max/Desired capacity
  - Scaling policies
  - Health checks
  - Multi-AZ distribution

#### **4.3 Elastic File System (EFS)**
- **EFS File System**: Shared storage for Jenkins home directory
- **Mount Targets**: In each availability zone
- **Security Groups**: For EFS access
- **Backup Policy**: Automated backups

#### **4.4 Elastic Load Balancer (ELB)**
- **Application Load Balancer**: Distributes traffic
- **Target Groups**: Routes to Jenkins instances
- **Health Checks**: Monitors instance health
- **Listeners**: HTTP/HTTPS configuration
- **SSL/TLS**: Certificate management

**Terraform Workflow**:
```bash
terraform init → terraform plan → terraform apply → Infrastructure Created
```

**Key Commands**:
1. **Initialize**: `terraform init`
2. **Plan**: `terraform plan -out=tfplan`
3. **Apply**: `terraform apply tfplan`
4. **Output**: Infrastructure resources created

**Configuration Structure**:
```
terraform/
├── main/
│   ├── main.tf           # Main infrastructure definition
│   ├── variables.tf      # Input variables
│   └── outputs.tf        # Output values
└── modules/
    ├── vpc/              # VPC module
    ├── efs/              # EFS module
    ├── elb/              # Load balancer module
    └── asg/              # Auto Scaling Group module
```

**What Gets Created**:
- ✅ VPC with public/private subnets
- ✅ Internet Gateway and NAT Gateways
- ✅ Security Groups
- ✅ EFS file system
- ✅ Application Load Balancer
- ✅ Auto Scaling Group with Launch Template
- ✅ S3 bucket for artifacts
- ✅ IAM roles and policies
- ✅ CloudWatch alarms

**Output**: Complete AWS infrastructure ready for Jenkins deployment

---

### **STEP 5: Shell Scripts for Automation**

**Purpose**: Automate various tasks that can't be handled by other tools, including post-deployment configuration and maintenance.

**What Shell Scripts Do**:
- **User Data Scripts**: Run on instance launch
- **Post-Deployment Setup**: Configure services after infrastructure is ready
- **Maintenance Tasks**: Updates, backups, cleanup
- **Integration Scripts**: Connect different tools and services

**Key Scripts**:

#### **5.1 User Data Script (ASG Launch Template)**
```bash
#!/bin/bash
# Mounts EFS, configures Jenkins, starts services

# Mount EFS
mount -t efs -o tls,iam fs-xxxxx:/ /var/lib/jenkins

# Configure Jenkins
systemctl start jenkins
systemctl enable jenkins

# Configure CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s
```

**Location**: `terraform/modules/asg/user-data.sh`

**Runs**: Automatically when EC2 instances launch

#### **5.2 Post-Deployment Configuration Script**
```bash
#!/bin/bash
# Configures Jenkins after infrastructure is ready

# Wait for Jenkins to be ready
until curl -f http://localhost:8080/login; do
  sleep 10
done

# Configure Jenkins via API
curl -X POST http://localhost:8080/configure \
  -d @jenkins-config.xml

# Install plugins
/usr/local/bin/install-plugins.sh pipeline docker aws-credentials
```

**Purpose**: Final configuration after instances are running

#### **5.3 Maintenance Scripts**
```bash
#!/bin/bash
# Backup Jenkins configuration
tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz /var/lib/jenkins

# Upload to S3
aws s3 cp jenkins-backup-*.tar.gz s3://jenkins-backups/

# Cleanup old backups
find /tmp -name "jenkins-backup-*.tar.gz" -mtime +7 -delete
```

**Purpose**: Automated backups and maintenance

**Common Use Cases**:
- EFS mounting and configuration
- Service startup and configuration
- CloudWatch agent setup
- Backup and restore operations
- Log rotation and cleanup
- Health check scripts
- Integration with external systems

**Output**: Fully configured and operational Jenkins instances

---

### **STEP 6: Jenkins Pipeline for Automating AMI Builds**

**Purpose**: Orchestrate and automate the entire workflow from AMI build to infrastructure deployment.

**What Jenkins Pipeline Does**:
- **Orchestrates**: Coordinates all tools in the correct sequence
- **Automates**: Runs the entire process without manual intervention
- **Monitors**: Tracks progress and reports status
- **Validates**: Ensures each step completes successfully
- **Notifies**: Sends alerts on success or failure

**Pipeline Stages**:

```groovy
pipeline {
    stages {
        // Stage 1: Checkout
        stage('Checkout') {
            // Get code, playbooks, configurations
        }
        
        // Stage 2: Build AMI with Packer
        stage('Build AMI') {
            // Run Packer to create Golden AMI
        }
        
        // Stage 3: Scan with Trivy
        stage('Scan AMI') {
            // Security scan with Trivy
        }
        
        // Stage 4: Deploy Infrastructure with Terraform
        stage('Deploy Infrastructure') {
            // Create AWS infrastructure
        }
        
        // Stage 5: Post-Deployment
        stage('Post-Deployment') {
            // Run shell scripts for final configuration
        }
    }
}
```

**Complete Pipeline Flow**:

```
┌─────────────────────────────────────────────────────────────┐
│                    JENKINS PIPELINE                          │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   STAGE 1    │    │   STAGE 2    │    │   STAGE 3    │
│  Checkout    │───▶│ Build AMI    │───▶│ Scan AMI     │
│              │    │  (Packer)    │    │  (Trivy)     │
└──────────────┘    └──────────────┘    └──────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │   STAGE 4    │
                    │ Deploy Infra │
                    │ (Terraform)  │
                    └──────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │   STAGE 5    │
                    │ Post-Deploy  │
                    │(Shell Scripts)│
                    └──────────────┘
```

**Key Features**:
- **Automated Triggers**: Git push, schedule, or manual
- **Parallel Execution**: Where possible for speed
- **Error Handling**: Retry logic and rollback
- **Artifact Storage**: S3, Jenkins artifacts
- **Notifications**: Slack, email, webhooks
- **Audit Trail**: Complete logs and history

**Benefits**:
- ✅ **Consistency**: Same process every time
- ✅ **Speed**: Automated execution
- ✅ **Reliability**: Error handling and validation
- ✅ **Traceability**: Complete audit trail
- ✅ **Scalability**: Can run multiple builds in parallel

---

## Complete Workflow Sequence

### **Phase 1: AMI Creation (Steps 1-3)**

```
1. Jenkins Pipeline Triggers
   ↓
2. Checkout Code & Playbooks
   ↓
3. Packer Builds AMI
   ├── Launches temp EC2
   ├── Ansible Configures (OS updates, Jenkins setup)
   └── Creates Golden AMI
   ↓
4. Trivy Scans AMI
   ├── Vulnerability scan
   ├── Generate report
   └── Pass/Fail decision
   ↓
5. If Pass: AMI tagged and stored
   If Fail: Build fails, AMI not used
```

### **Phase 2: Infrastructure Deployment (Steps 4-5)**

```
6. Terraform Creates Infrastructure
   ├── VPC, Subnets, IGW, NAT
   ├── EFS file system
   ├── Application Load Balancer
   ├── Auto Scaling Group
   └── Launch Template (uses Golden AMI)
   ↓
7. ASG Launches Instances
   ├── Uses Golden AMI from Step 1
   ├── User data script runs
   ├── EFS mounted
   └── Jenkins starts
   ↓
8. Shell Scripts Configure
   ├── Final Jenkins configuration
   ├── CloudWatch setup
   └── Health checks
   ↓
9. Infrastructure Ready
   └── Jenkins accessible via ALB
```

---

## Tool Integration Matrix

| Step | Tool | Input | Output | Next Step |
|------|------|-------|--------|-----------|
| 1 | Packer | Base AMI | Golden AMI | Step 3 (Trivy) |
| 2 | Ansible | Playbooks | Configured Instance | Part of Step 1 |
| 3 | Trivy | Golden AMI | Security Report | Step 4 (Terraform) |
| 4 | Terraform | AMI ID + Config | AWS Infrastructure | Step 5 (Scripts) |
| 5 | Shell Scripts | Infrastructure | Configured Services | Complete |
| 6 | Jenkins | All Tools | Orchestrated Workflow | All Steps |

---

## Best Practices

### **1. Version Control**
- Store all configurations in Git
- Tag AMIs with version numbers
- Maintain changelog

### **2. Security**
- Scan AMIs before use
- Use encrypted AMIs
- Rotate credentials regularly
- Apply least privilege IAM policies

### **3. Testing**
- Test AMIs in staging first
- Validate infrastructure changes
- Run integration tests

### **4. Monitoring**
- Track AMI build times
- Monitor infrastructure costs
- Set up alerts for failures

### **5. Documentation**
- Document all configurations
- Maintain runbooks
- Keep architecture diagrams updated

---

## Example: Complete Execution

```bash
# 1. Jenkins Pipeline Starts
$ jenkins job trigger golden-ami-build

# 2. Packer Builds AMI
$ packer build jenkins-ami.pkr.hcl
# Output: ami-0abc123def456789

# 3. Trivy Scans AMI
$ trivy image ami-0abc123def456789
# Output: Scan report, vulnerabilities found

# 4. Terraform Deploys Infrastructure
$ terraform apply -var="jenkins_ami_id=ami-0abc123def456789"
# Output: Infrastructure created

# 5. Shell Scripts Configure
$ ./post-deployment.sh
# Output: Jenkins configured and ready

# 6. Verify
$ curl http://alb-dns-name/login
# Output: Jenkins login page
```

---

## Conclusion

This workflow demonstrates a complete DevOps pipeline that:

1. **Builds** standardized AMIs with Packer
2. **Configures** systems with Ansible
3. **Scans** for security with Trivy
4. **Deploys** infrastructure with Terraform
5. **Automates** tasks with Shell Scripts
6. **Orchestrates** everything with Jenkins

Each tool plays a specific role, and together they create a robust, automated, and secure infrastructure deployment process.

