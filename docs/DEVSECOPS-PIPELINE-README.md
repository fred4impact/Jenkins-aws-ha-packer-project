# Production Grade DevSecOps Build Pipeline

This Jenkins pipeline implements a complete DevSecOps workflow with security scanning, quality gates, and containerization.

## Pipeline Stages

The pipeline consists of 9 stages that run in sequence:

1. **Build & Unit Test** - Compiles the application and runs unit tests using Maven
2. **Code Coverage** - Generates code coverage reports using JaCoCo
3. **SCA** - Software Composition Analysis using OWASP Dependency-Check
4. **SAST** - Static Application Security Testing using SpotBugs and SonarQube
5. **Quality Gates** - Validates code quality using SonarQube quality gates
6. **Build Image** - Builds Docker container image from Dockerfile
7. **Scan Image** - Scans Docker image for vulnerabilities using Aqua Trivy
8. **Smoke Test** - Runs basic smoke tests on the containerized application
9. **Push Image** - Pushes the Docker image to registry (optional)

## Prerequisites

### Jenkins Setup

1. **Required Jenkins Plugins:**
   - Pipeline Plugin
   - Maven Integration Plugin
   - JaCoCo Plugin
   - HTML Publisher Plugin
   - Docker Pipeline Plugin
   - SonarQube Scanner Plugin
   - OWASP Dependency-Check Plugin
   - SpotBugs Plugin
   - Slack Notification Plugin (optional)
   - Email Extension Plugin (optional)

2. **Tools on Jenkins Agent:**
   - Java JDK 17
   - Maven 3.9.5
   - Docker
   - Git
   - curl
   - jq (for JSON parsing)

### External Services

1. **SonarQube Server**
   - Running and accessible at `SONAR_HOST_URL`
   - SonarQube token configured in Jenkins credentials

2. **Docker Registry** (optional)
   - Docker Hub, AWS ECR, or private registry
   - Credentials configured in Jenkins

3. **Notification Channels** (optional)
   - Slack webhook configured
   - Email server configured

## Configuration

### 1. Jenkins Credentials Setup

Configure the following credentials in Jenkins:

#### SonarQube Token
- **ID**: `sonar-token`
- **Type**: Secret text
- **Value**: Your SonarQube authentication token

#### Docker Registry Credentials (if pushing images)
- **ID**: `docker-registry-credentials`
- **Type**: Username with password
- **Username**: Docker registry username
- **Password**: Docker registry password/token

### 2. Environment Variables

Update the following environment variables in the Jenkinsfile:

```groovy
environment {
    JAVA_VERSION = '17'
    MAVEN_VERSION = '3.9.5'
    APP_NAME = 'my-application'                    // Change to your app name
    DOCKER_REGISTRY = 'your-registry.io'           // Change to your registry
    SONAR_HOST_URL = 'http://sonarqube:9000'       // Change to your SonarQube URL
    SLACK_CHANNEL = '#devops-alerts'                // Change to your Slack channel
    EMAIL_RECIPIENTS = 'devops-team@yourcompany.com' // Change to your email
}
```

### 3. Maven Project Structure

Your Maven project should have the following structure:

```
project-root/
├── src/
│   ├── main/
│   │   └── java/
│   └── test/
│       └── java/
├── pom.xml
└── Dockerfile
```

### 4. Required Maven Plugins

Add these plugins to your `pom.xml`:

```xml
<build>
    <plugins>
        <!-- JaCoCo for Code Coverage -->
        <plugin>
            <groupId>org.jacoco</groupId>
            <artifactId>jacoco-maven-plugin</artifactId>
            <version>0.8.10</version>
            <executions>
                <execution>
                    <goals>
                        <goal>prepare-agent</goal>
                    </goals>
                </execution>
                <execution>
                    <id>report</id>
                    <phase>test</phase>
                    <goals>
                        <goal>report</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        
        <!-- OWASP Dependency-Check for SCA -->
        <plugin>
            <groupId>org.owasp</groupId>
            <artifactId>dependency-check-maven</artifactId>
            <version>9.0.9</version>
            <executions>
                <execution>
                    <goals>
                        <goal>check</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        
        <!-- SpotBugs for SAST -->
        <plugin>
            <groupId>com.github.spotbugs</groupId>
            <artifactId>spotbugs-maven-plugin</artifactId>
            <version>4.8.2.0</version>
        </plugin>
        
        <!-- SonarQube Scanner -->
        <plugin>
            <groupId>org.sonarsource.scanner.maven</groupId>
            <artifactId>sonar-maven-plugin</artifactId>
            <version>3.10.0.2594</version>
        </plugin>
    </plugins>
</build>
```

### 5. Dockerfile Example

Create a `Dockerfile` in your project root:

```dockerfile
FROM openjdk:17-jdk-slim

WORKDIR /app

# Copy Maven build artifact
COPY target/*.jar app.jar

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD curl -f http://localhost:8080/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 6. Application Health Endpoints

Your application should expose these endpoints for smoke tests:

- `GET /health` - Health check endpoint
- `GET /api/status` - Application status endpoint

## Usage

### Option 1: Pipeline from SCM

1. Create a new Pipeline job in Jenkins
2. Configure:
   - **Pipeline Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your repository URL
   - **Branch**: `*/main` (or your branch)
   - **Script Path**: `Jenkinsfile.devsecops`

### Option 2: Copy Pipeline Script

1. Create a new Pipeline job in Jenkins
2. Copy the contents of `Jenkinsfile.devsecops` into the pipeline script editor
3. Save and run

## Quality Gates and Thresholds

The pipeline enforces the following quality gates:

### Code Coverage
- **Threshold**: 80%
- **Action**: Pipeline fails if coverage is below threshold

### SCA (Dependency Vulnerabilities)
- **Critical**: 0 allowed (pipeline fails)
- **High**: Maximum 10 allowed (pipeline fails if exceeded)
- **Medium**: Warning only

### SAST
- Results published to SonarQube
- Quality gate status checked

### Image Scanning (Trivy)
- **Critical**: 0 allowed (pipeline fails)
- **High**: Maximum 5 allowed (pipeline fails if exceeded)

## Reports and Artifacts

The pipeline generates and publishes the following reports:

1. **JUnit Test Results** - Unit test results
2. **JaCoCo Coverage Report** - Code coverage HTML report
3. **OWASP Dependency-Check Report** - Dependency vulnerability report
4. **SpotBugs Report** - Static analysis findings
5. **SonarQube Dashboard** - Comprehensive code quality metrics
6. **Trivy Scan Report** - Container image security scan

All reports are accessible from the Jenkins build page.

## Notifications

### Slack Notifications

Uncomment the Slack notification sections in the `post` block:

```groovy
slackSend(
    channel: env.SLACK_CHANNEL,
    color: 'good',
    message: "✅ DevSecOps Pipeline Succeeded..."
)
```

Configure Slack webhook in Jenkins:
- **Manage Jenkins** → **Configure System** → **Slack**
- Add Slack workspace and channel

### Email Notifications

Uncomment the email notification sections in the `post` block:

```groovy
emailext(
    subject: "❌ DevSecOps Pipeline Failed...",
    body: "...",
    to: env.EMAIL_RECIPIENTS
)
```

## Troubleshooting

### Common Issues

1. **Maven Build Fails**
   - Check Java version compatibility
   - Verify Maven dependencies are accessible
   - Check network connectivity to Maven repositories

2. **SonarQube Connection Fails**
   - Verify SonarQube server is running
   - Check `SONAR_HOST_URL` is correct
   - Verify SonarQube token is valid

3. **Docker Build Fails**
   - Ensure Docker is running on Jenkins agent
   - Check Dockerfile syntax
   - Verify build context includes required files

4. **Trivy Scan Fails**
   - Ensure Docker daemon is accessible
   - Check Docker image exists locally
   - Verify Trivy image can be pulled

5. **Smoke Tests Fail**
   - Check application health endpoints are implemented
   - Verify application starts correctly in container
   - Check port mappings

### Debug Mode

Enable verbose logging by adding to pipeline:

```groovy
options {
    // ... existing options
    echo "Debug mode enabled"
}
```

## Best Practices

1. **Security**
   - Never commit credentials to Git
   - Use Jenkins credentials for sensitive data
   - Rotate tokens regularly
   - Review security scan reports

2. **Performance**
   - Use Docker layer caching
   - Parallelize stages where possible
   - Cache Maven dependencies

3. **Maintenance**
   - Keep tools updated (Trivy, OWASP Dependency-Check, etc.)
   - Review and update quality gate thresholds
   - Monitor pipeline execution times

4. **Compliance**
   - Archive all scan reports
   - Maintain audit trail
   - Document security exceptions

## Customization

### Adjust Quality Gate Thresholds

Modify thresholds in the pipeline:

```groovy
// Code Coverage threshold
if (coveragePercent < 80) {  // Change 80 to your threshold
    error("Code coverage below threshold")
}

// SCA thresholds
if (highCount > 10) {  // Change 10 to your threshold
    error("Too many high severity vulnerabilities")
}

// Trivy thresholds
if (highCount > 5) {  // Change 5 to your threshold
    error("Too many high severity vulnerabilities")
}
```

### Add Additional Stages

Add custom stages before the `post` block:

```groovy
stage('Custom Stage') {
    steps {
        script {
            echo "Running custom stage..."
            // Your custom logic here
        }
    }
}
```

### Parallel Execution

Run independent stages in parallel:

```groovy
parallel {
    stage('Stage A') {
        steps { /* ... */ }
    }
    stage('Stage B') {
        steps { /* ... */ }
    }
}
```

## Support

For issues or questions:
1. Check Jenkins build logs
2. Review published reports
3. Verify configuration and credentials
4. Check external service status (SonarQube, Docker registry)

