# Jenkins Pipeline for Golden AMI Build Process

This guide explains how to automate the Golden AMI build process (Stage I: Checkout, Stage II: Build, Stage III: Scan) using a Jenkins pipeline.

## Overview

The pipeline automates the complete workflow:
1. **Stage I**: Checkout playbook and configuration files
2. **Stage II**: Build Golden AMI using HashiCorp Packer
3. **Stage III**: Scan the AMI for security vulnerabilities using Aqua Trivy

## Prerequisites

### Jenkins Setup
- Jenkins instance with necessary plugins installed
- AWS credentials configured in Jenkins
- Required tools installed on Jenkins agents

### Required Jenkins Plugins
- **Pipeline Plugin** (built-in)
- **AWS Steps Plugin** (for AWS operations)
- **Credentials Binding Plugin** (for secure credential management)
- **Ansible Plugin** (if using Ansible provisioner)
- **Docker Pipeline Plugin** (if using Docker for Trivy)

### Required Tools on Jenkins Agent
- **Packer** (>= 1.8.0)
- **AWS CLI** (v2)
- **Terraform** (optional, for infrastructure)
- **Docker** (for running Trivy scanner)
- **Git** (for checkout)

### AWS Configuration
- IAM role or credentials with permissions to:
  - Create/delete EC2 instances
  - Create/manage AMIs
  - Access S3 (for storing artifacts)
  - Create/manage EBS snapshots

## Pipeline Structure

```
Jenkins Pipeline
├── Stage I: Checkout
│   ├── Checkout playbook repository
│   ├── Checkout Packer configuration
│   └── Validate files
├── Stage II: Build Golden AMI
│   ├── Initialize Packer
│   ├── Validate Packer configuration
│   ├── Build AMI with Packer
│   └── Store AMI ID
└── Stage III: Scan AMI
    ├── Pull Trivy scanner
    ├── Scan AMI for vulnerabilities
    ├── Generate security report
    └── Fail pipeline if critical issues found
```

## Jenkinsfile: Complete Pipeline

### Option 1: Declarative Pipeline (Recommended)

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        PACKER_VERSION = '1.10.0'
        JENKINS_VERSION = '2.414.3'
        JAVA_VERSION = '17'
        TRIVY_VERSION = 'latest'
        
        // AWS Credentials (configured in Jenkins)
        AWS_CREDENTIALS_ID = 'aws-credentials'
        
        // S3 bucket for storing artifacts
        S3_ARTIFACT_BUCKET = 'jenkins-ami-artifacts'
        
        // Notification settings
        SLACK_CHANNEL = '#devops-alerts'
    }
    
    options {
        timeout(time: 2, unit: 'HOURS')
        timestamps()
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    stages {
        // ============================================
        // STAGE I: CHECKOUT
        // ============================================
        stage('Stage I: Checkout') {
            steps {
                script {
                    echo "============================================"
                    echo "STAGE I: CHECKOUT PLAYBOOK AND CONFIGURATION"
                    echo "============================================"
                }
                
                // Checkout Packer configuration repository
                checkout scm
                
                // Checkout playbook repository (if separate)
                dir('playbooks') {
                    git branch: 'main',
                        url: 'https://github.com/your-org/jenkins-playbooks.git',
                        credentialsId: 'github-credentials'
                }
                
                // Validate required files exist
                script {
                    def requiredFiles = [
                        'packer/jenkins-ami.pkr.hcl',
                        'packer/scripts/install-jenkins.sh',
                        'playbooks/jenkins-setup.yml'
                    ]
                    
                    requiredFiles.each { file ->
                        if (!fileExists(file)) {
                            error("Required file not found: ${file}")
                        }
                    }
                    
                    echo "✓ All required files checked out successfully"
                }
                
                // Archive files for later stages
                archiveArtifacts artifacts: 'packer/**', fingerprint: true
                archiveArtifacts artifacts: 'playbooks/**', fingerprint: true
            }
        }
        
        // ============================================
        // STAGE II: BUILD GOLDEN AMI
        // ============================================
        stage('Stage II: Build Golden AMI') {
            steps {
                script {
                    echo "============================================"
                    echo "STAGE II: BUILD GOLDEN AMI WITH PACKER"
                    echo "============================================"
                }
                
                dir('packer') {
                    // Initialize Packer
                    sh '''
                        echo "Initializing Packer..."
                        packer init .
                    '''
                    
                    // Validate Packer configuration
                    sh '''
                        echo "Validating Packer configuration..."
                        packer validate jenkins-ami.pkr.hcl
                    '''
                    
                    // Build AMI with AWS credentials
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: env.AWS_CREDENTIALS_ID,
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        script {
                            def buildCommand = """
                                packer build \
                                    -var 'aws_region=${AWS_REGION}' \
                                    -var 'jenkins_version=${JENKINS_VERSION}' \
                                    -var 'java_version=${JAVA_VERSION}' \
                                    jenkins-ami.pkr.hcl
                            """
                            
                            echo "Building Golden AMI..."
                            def buildOutput = sh(
                                script: buildCommand,
                                returnStdout: true
                            )
                            
                            // Extract AMI ID from Packer output
                            def amiId = sh(
                                script: "echo '${buildOutput}' | grep -oP 'ami-[a-z0-9]+' | tail -1",
                                returnStdout: true
                            ).trim()
                            
                            if (!amiId) {
                                error("Failed to extract AMI ID from Packer output")
                            }
                            
                            // Store AMI ID as environment variable and build parameter
                            env.AMI_ID = amiId
                            currentBuild.description = "AMI: ${amiId}"
                            
                            echo "✓ Golden AMI built successfully: ${amiId}"
                            
                            // Save AMI ID to file for next stage
                            writeFile file: 'ami-id.txt', text: amiId
                            
                            // Upload AMI ID to S3 for tracking
                            sh """
                                aws s3 cp ami-id.txt \
                                    s3://${S3_ARTIFACT_BUCKET}/amis/${BUILD_NUMBER}/ami-id.txt \
                                    --region ${AWS_REGION}
                            """
                        }
                    }
                }
            }
        }
        
        // ============================================
        // STAGE III: SCAN AMI
        // ============================================
        stage('Stage III: Scan AMI') {
            steps {
                script {
                    echo "============================================"
                    echo "STAGE III: SCAN GOLDEN AMI WITH AQUA TRIVY"
                    echo "============================================"
                    
                    // Read AMI ID from previous stage
                    def amiId = readFile('packer/ami-id.txt').trim()
                    env.AMI_ID = amiId
                    
                    echo "Scanning AMI: ${amiId}"
                }
                
                // Run Trivy scan on the AMI
                script {
                    def amiId = env.AMI_ID
                    def scanReport = "trivy-scan-report-${BUILD_NUMBER}.json"
                    def scanReportHtml = "trivy-scan-report-${BUILD_NUMBER}.html"
                    
                    // Pull latest Trivy image
                    sh "docker pull aquasec/trivy:${TRIVY_VERSION}"
                    
                    // Scan AMI using Trivy
                    sh """
                        docker run --rm \
                            -v \$(pwd):/workspace \
                            -w /workspace \
                            -e AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID} \
                            -e AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY} \
                            -e AWS_DEFAULT_REGION=${AWS_REGION} \
                            aquasec/trivy:${TRIVY_VERSION} \
                            image --format json \
                            --output ${scanReport} \
                            --exit-code 0 \
                            --severity HIGH,CRITICAL \
                            ${amiId}
                    """
                    
                    // Generate HTML report
                    sh """
                        docker run --rm \
                            -v \$(pwd):/workspace \
                            -w /workspace \
                            -e AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID} \
                            -e AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY} \
                            -e AWS_DEFAULT_REGION=${AWS_REGION} \
                            aquasec/trivy:${TRIVY_VERSION} \
                            image --format template \
                            --template '@contrib/html.tpl' \
                            --output ${scanReportHtml} \
                            --severity HIGH,CRITICAL \
                            ${amiId}
                    """
                    
                    // Parse scan results
                    def scanResults = readJSON file: scanReport
                    def criticalCount = 0
                    def highCount = 0
                    
                    scanResults.Results.each { result ->
                        result.Vulnerabilities.each { vuln ->
                            if (vuln.Severity == 'CRITICAL') {
                                criticalCount++
                            } else if (vuln.Severity == 'HIGH') {
                                highCount++
                            }
                        }
                    }
                    
                    // Publish HTML report
                    publishHTML([
                        reportName: 'Trivy Security Scan Report',
                        reportDir: '.',
                        reportFiles: scanReportHtml,
                        keepAll: true,
                        alwaysLinkToLastBuild: true
                    ])
                    
                    // Upload reports to S3
                    sh """
                        aws s3 cp ${scanReport} \
                            s3://${S3_ARTIFACT_BUCKET}/scans/${BUILD_NUMBER}/trivy-report.json \
                            --region ${AWS_REGION}
                        aws s3 cp ${scanReportHtml} \
                            s3://${S3_ARTIFACT_BUCKET}/scans/${BUILD_NUMBER}/trivy-report.html \
                            --region ${AWS_REGION}
                    """
                    
                    // Fail pipeline if critical vulnerabilities found
                    if (criticalCount > 0) {
                        error("❌ CRITICAL: Found ${criticalCount} critical vulnerabilities. AMI cannot be used in production.")
                    }
                    
                    if (highCount > 0) {
                        echo "⚠️  WARNING: Found ${highCount} high severity vulnerabilities. Review before production use."
                    }
                    
                    echo "✓ Security scan completed: ${criticalCount} critical, ${highCount} high severity issues"
                }
            }
        }
        
        // ============================================
        // POST-BUILD: NOTIFICATION & CLEANUP
        // ============================================
        stage('Post-Build: Tag AMI and Notify') {
            steps {
                script {
                    def amiId = env.AMI_ID
                    
                    // Tag AMI with build information
                    sh """
                        aws ec2 create-tags \
                            --resources ${amiId} \
                            --tags \
                                Key=BuildNumber,Value=${BUILD_NUMBER} \
                                Key=BuildDate,Value=\$(date +%Y-%m-%d) \
                                Key=JenkinsJob,Value=${JOB_NAME} \
                                Key=JenkinsBuild,Value=${BUILD_URL} \
                                Key=Status,Value=Scanned \
                            --region ${AWS_REGION}
                    """
                    
                    // Share AMI ID as build artifact
                    writeFile file: 'build-info.txt', text: """
                        AMI ID: ${amiId}
                        Build Number: ${BUILD_NUMBER}
                        Build Date: \$(date)
                        Jenkins Job: ${JOB_NAME}
                        Jenkins Build: ${BUILD_URL}
                    """
                    
                    archiveArtifacts artifacts: 'build-info.txt', fingerprint: true
                    
                    echo "✓ AMI tagged and build information archived"
                }
            }
        }
    }
    
    post {
        success {
            script {
                def amiId = env.AMI_ID
                echo "✅ Pipeline succeeded! Golden AMI: ${amiId}"
                
                // Send success notification (Slack, email, etc.)
                // slackSend(
                //     channel: env.SLACK_CHANNEL,
                //     color: 'good',
                //     message: "✅ Golden AMI build succeeded!\nAMI ID: ${amiId}\nBuild: ${BUILD_URL}"
                // )
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed! Check logs for details."
                
                // Send failure notification
                // slackSend(
                //     channel: env.SLACK_CHANNEL,
                //     color: 'danger',
                //     message: "❌ Golden AMI build failed!\nBuild: ${BUILD_URL}"
                // )
            }
        }
        
        always {
            // Cleanup temporary files
            cleanWs()
        }
    }
}
```

### Option 2: Scripted Pipeline (Advanced)

```groovy
node {
    def AWS_REGION = 'us-east-1'
    def AMI_ID = null
    
    try {
        // Stage I: Checkout
        stage('Stage I: Checkout') {
            echo "Checking out playbook and configuration..."
            checkout scm
            dir('playbooks') {
                git branch: 'main',
                    url: 'https://github.com/your-org/jenkins-playbooks.git'
            }
        }
        
        // Stage II: Build AMI
        stage('Stage II: Build Golden AMI') {
            dir('packer') {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'packer init .'
                    sh 'packer validate jenkins-ami.pkr.hcl'
                    
                    def output = sh(
                        script: 'packer build jenkins-ami.pkr.hcl',
                        returnStdout: true
                    )
                    
                    AMI_ID = (output =~ /ami-[a-z0-9]+/).findAll().last()
                    echo "AMI built: ${AMI_ID}"
                }
            }
        }
        
        // Stage III: Scan AMI
        stage('Stage III: Scan AMI') {
            sh """
                docker run --rm \
                    -e AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID} \
                    -e AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY} \
                    -e AWS_DEFAULT_REGION=${AWS_REGION} \
                    aquasec/trivy image --exit-code 1 --severity CRITICAL ${AMI_ID}
            """
        }
        
        // Success
        currentBuild.result = 'SUCCESS'
        echo "Pipeline completed successfully. AMI: ${AMI_ID}"
        
    } catch (Exception e) {
        currentBuild.result = 'FAILURE'
        echo "Pipeline failed: ${e.getMessage()}"
        throw e
    }
}
```

## Jenkins Configuration Steps

### Step 1: Install Required Plugins

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Install the following plugins:
   - Pipeline
   - AWS Steps
   - Credentials Binding
   - HTML Publisher (for Trivy reports)
   - Ansible (if using Ansible provisioner)

### Step 2: Configure AWS Credentials

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Add AWS credentials:
   - **Kind**: AWS Credentials
   - **ID**: `aws-credentials`
   - **Access Key ID**: Your AWS access key
   - **Secret Access Key**: Your AWS secret key
   - **Description**: AWS credentials for Packer and Trivy

### Step 3: Configure GitHub Credentials (if needed)

1. Add GitHub credentials:
   - **Kind**: Username with password or SSH Username with private key
   - **ID**: `github-credentials`
   - **Username**: Your GitHub username
   - **Password/Private Key**: Your GitHub token or SSH key

### Step 4: Install Tools on Jenkins Agent

Ensure the following tools are installed on your Jenkins agent:

```bash
# Install Packer
wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
unzip packer_1.10.0_linux_amd64.zip
sudo mv packer /usr/local/bin/

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Docker (for Trivy)
sudo yum install -y docker
sudo systemctl start docker
sudo usermod -aG docker jenkins

# Verify installations
packer version
aws --version
docker --version
```

### Step 5: Create Jenkins Pipeline Job

1. Go to **New Item** → **Pipeline**
2. Name: `golden-ami-build`
3. Configure:
   - **Pipeline Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your repository URL
   - **Branch**: `*/main` (or your branch)
   - **Script Path**: `Jenkinsfile` (or your pipeline file name)

### Step 6: Configure Pipeline Parameters (Optional)

Add build parameters for flexibility:

```groovy
parameters {
    choice(
        name: 'AWS_REGION',
        choices: ['us-east-1', 'us-west-2', 'eu-west-1'],
        description: 'AWS Region for AMI build'
    )
    string(
        name: 'JENKINS_VERSION',
        defaultValue: '2.414.3',
        description: 'Jenkins version to install'
    )
    booleanParam(
        name: 'SKIP_SCAN',
        defaultValue: false,
        description: 'Skip security scan (not recommended)'
    )
}
```

## Enhanced Pipeline with Ansible Provisioner

If using Ansible in Stage II:

```groovy
stage('Stage II: Build Golden AMI') {
    steps {
        dir('packer') {
            // Install Ansible if not present
            sh '''
                if ! command -v ansible &> /dev/null; then
                    pip3 install ansible
                fi
            '''
            
            // Run Packer with Ansible provisioner
            withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: env.AWS_CREDENTIALS_ID
            ]]) {
                sh '''
                    packer build \
                        -var 'aws_region=${AWS_REGION}' \
                        -var-file='../playbooks/vars.yml' \
                        jenkins-ami.pkr.hcl
                '''
            }
        }
    }
}
```

## Packer Configuration with Ansible

Update `packer/jenkins-ami.pkr.hcl` to include Ansible provisioner:

```hcl
build {
  sources = ["source.amazon-ebs.jenkins"]
  
  provisioner "ansible" {
    playbook_file = "../playbooks/jenkins-setup.yml"
    extra_arguments = [
      "--extra-vars", "jenkins_version=${var.jenkins_version}",
      "--extra-vars", "java_version=${var.java_version}"
    ]
  }
  
  provisioner "shell" {
    script = "scripts/install-jenkins.sh"
  }
}
```

## Monitoring and Notifications

### Add Slack Notifications

```groovy
post {
    success {
        slackSend(
            channel: '#devops-alerts',
            color: 'good',
            message: """
                ✅ Golden AMI Build Succeeded
                AMI ID: ${env.AMI_ID}
                Build: ${BUILD_URL}
            """
        )
    }
    failure {
        slackSend(
            channel: '#devops-alerts',
            color: 'danger',
            message: """
                ❌ Golden AMI Build Failed
                Build: ${BUILD_URL}
                Check logs for details.
            """
        )
    }
}
```

### Add Email Notifications

```groovy
post {
    always {
        emailext(
            subject: "Golden AMI Build: ${currentBuild.currentResult}",
            body: """
                Build: ${BUILD_URL}
                AMI ID: ${env.AMI_ID ?: 'N/A'}
                Status: ${currentBuild.currentResult}
            """,
            to: 'devops-team@yourcompany.com'
        )
    }
}
```

## Best Practices

### 1. **Version Control**
- Store Jenkinsfile in Git
- Use version tags for AMIs
- Maintain changelog

### 2. **Security**
- Use Jenkins credentials for sensitive data
- Rotate AWS credentials regularly
- Scan AMIs before production use
- Never commit credentials to Git

### 3. **Error Handling**
- Add retry logic for transient failures
- Implement proper cleanup on failure
- Log all operations for debugging

### 4. **Performance**
- Use parallel stages where possible
- Cache Docker images
- Optimize Packer build time

### 5. **Compliance**
- Generate audit logs
- Store scan reports
- Tag AMIs with metadata

## Troubleshooting

### Common Issues

1. **Packer build fails**
   - Check AWS credentials
   - Verify IAM permissions
   - Check instance type availability

2. **Trivy scan fails**
   - Ensure Docker is running
   - Check AWS credentials for image access
   - Verify AMI is accessible

3. **Checkout fails**
   - Verify repository access
   - Check credentials configuration
   - Ensure branch exists

## Conclusion

This Jenkins pipeline automates the complete Golden AMI build process:
- **Stage I**: Automated checkout of playbooks and configuration
- **Stage II**: Automated AMI building with Packer
- **Stage III**: Automated security scanning with Trivy

The pipeline ensures consistency, security, and traceability in your AMI build process.

