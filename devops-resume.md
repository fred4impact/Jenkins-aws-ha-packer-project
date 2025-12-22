# DevOps / SRE Engineer Resume

---

## PROFESSIONAL PROFILE

DevOps Engineer specializing in designing, automating, and securing scalable cloud-native infrastructure using AWS, Terraform, and Infrastructure as Code. Proven experience building highly available CI/CD platforms, implementing DevSecOps pipelines with automated security scanning, and orchestrating containerized deployments. Strong background in infrastructure automation, observability, and SRE practices. Experienced in supporting production environments and enabling zero-downtime releases with multi-AZ architectures. Currently pursuing the Certified Kubernetes Administrator (CKA).

**Key Strengths:** Infrastructure as Code | Automation | High Availability | DevSecOps | Cloud Security | Cost Optimisation | CI/CD Pipeline Design

---

## CORE COMPETENCIES

- AWS Infrastructure Design & Architecture
- Terraform & Infrastructure as Code
- Packer & Golden AMI Management
- Ansible Configuration Management
- VPC / Networking & Subnets
- IAM & Cloud Security
- Load Balancing & Auto Scaling
- High Availability & Disaster Recovery
- CI/CD Pipeline Development
- DevSecOps & Security Automation
- Monitoring & Observability
- Cloud Cost Optimisation

---

## TECHNICAL SKILLS

**Cloud:** AWS – EC2, VPC, EFS, S3, ALB, Auto Scaling Groups, IAM, Security Groups, NAT Gateways, CloudWatch

**Infrastructure as Code:** Terraform, Packer, CloudFormation, Ansible

**CI/CD:** Jenkins, GitLab CI/CD, GitHub Actions, Jenkins Pipelines (Groovy)

**Containers:** Docker, Dockerfile, Container Security Scanning

**Monitoring:** CloudWatch, Prometheus, Grafana, Log Aggregation

**Security:** IAM, Security Groups, Trivy, OWASP Dependency-Check, SonarQube, SAST/SCA tools, Secrets Management

**Version Control:** Git, GitLab, GitHub

**Scripting:** Bash, Groovy, Python

**Operating Systems:** Linux (Ubuntu, RHEL, Amazon Linux)

---

## PROFESSIONAL EXPERIENCE

### DevOps Engineer
**Capgemini – London, UK**  
*Month, Year – Present*

- Architected and deployed production-grade, highly available Jenkins CI/CD platform on AWS using Terraform, implementing multi-AZ deployment with Auto Scaling Groups, Application Load Balancer, and EFS shared storage for zero-downtime operations

- Built organization-specific Golden AMIs using HashiCorp Packer with Ansible playbooks, reducing deployment time by 70% and ensuring consistent, hardened Jenkins instances across environments

- Developed reusable Terraform modules for VPC, EFS, ELB, and ASG provisioning, enabling rapid infrastructure deployment and reducing configuration errors by 85%

- Implemented comprehensive DevSecOps pipeline with integrated security scanning (Trivy, OWASP Dependency-Check, SonarQube), SAST/SCA analysis, and automated quality gates, improving security posture and compliance

- Designed secure VPC architecture with public/private subnets, NAT gateways, security groups, and IAM roles following least-privilege principles for network isolation and access control

- Automated Jenkins configuration management using Ansible roles for security hardening, plugin installation, and HA setup, ensuring consistent state across all instances

- Integrated S3 lifecycle policies and EFS backup strategies, reducing storage costs by 35% while maintaining compliance with data retention requirements

- Implemented CloudWatch monitoring, logging, and alerting for production systems, enabling proactive incident detection and reducing MTTR by 50%

- Supported production environments through incident response, root cause analysis, and infrastructure troubleshooting, maintaining 99.9% uptime SLA

**Key Technologies:** Terraform, Packer, Ansible, Jenkins, AWS (EC2, VPC, EFS, S3, ALB, ASG), Docker, DevSecOps Tools

---

### Lead Automation Engineer
**HMRC – Capgemini, London, UK**  
*Month, Year – Month, Year*

- Built scalable automation frameworks using Java, TestNG, Selenium, and RestAssured for web and API testing

- Integrated automated testing into CI/CD pipelines for quality gates, regression coverage, and comprehensive reporting

- Collaborated with DevOps teams to ensure test automation aligned with containerized and cloud-native deployment models

- Reduced manual testing effort by 80% through comprehensive test automation

---

### Automation Engineer
**MC-DONALD – Capgemini, London, UK**  
*Month, Year – Month, Year*

- Built scalable automation frameworks using Java, TestNG, Selenium, and RestAssured for web and API testing

- Integrated automated testing into CI/CD pipelines for quality gates, regression coverage, and comprehensive reporting

- Collaborated with DevOps teams to ensure test automation aligned with containerized and cloud-native deployment models

- Reduced manual testing effort by 80% through comprehensive test automation

---

## KEY CLOUD PROJECTS

### Scalable Event Booking System on AWS

**Objective:** Designed and implemented a production-grade, highly available event booking system on AWS with horizontal scalability, concurrency handling, and automated CI/CD pipelines to support high-traffic booking scenarios.

**Key Achievements:**
- Architected scalable microservices infrastructure using ECS Fargate with Application Load Balancer and CloudFront CDN, enabling horizontal auto-scaling to handle peak booking traffic and reducing latency by 40%
- Implemented Infrastructure as Code using Terraform to provision multi-tier architecture including RDS PostgreSQL, ElastiCache Redis, SQS queues, and VPC with public/private subnets across multiple availability zones
- Built GitLab CI/CD pipelines with automated container builds, security scanning, and blue-green deployment strategies, enabling zero-downtime releases and reducing deployment time by 65%
- Designed Redis-based distributed locking mechanism for seat reservation concurrency control, preventing double-booking scenarios and ensuring data consistency across distributed services

**Technologies:** Terraform, GitLab CI/CD, AWS (ECS Fargate, RDS, ElastiCache Redis, SQS, ALB, CloudFront, VPC, CloudWatch), Docker, IAM, AWS WAF

**Outcomes:**
- **Zero double-booking incidents** achieved through Redis distributed locking implementation
- **40% latency reduction** via CloudFront CDN and caching strategies
- **65% faster deployments** through automated CI/CD pipelines
- **99.9% availability** with multi-AZ architecture and auto-scaling capabilities

---

### Production-Grade High Availability Jenkins Platform on AWS

**Objective:** Designed and implemented a highly available, scalable Jenkins CI/CD platform on AWS with zero-downtime capabilities, automated scaling, and comprehensive security hardening.

**Key Achievements:**
- Architected multi-AZ deployment with Auto Scaling Groups (2-5 instances) and Application Load Balancer for traffic distribution
- Implemented EFS shared storage for Jenkins home directory, enabling seamless failover and session persistence
- Built custom Golden AMIs using Packer and Ansible, reducing deployment time by 70% and ensuring consistent, hardened configurations
- Developed modular Terraform infrastructure with reusable modules for VPC, EFS, ELB, and ASG
- Integrated comprehensive security controls: security groups, IAM roles, encryption at rest (EFS, S3), and network isolation
- Achieved 99.9% uptime with automatic failover and health check-based instance replacement

**Technologies:** Terraform, Packer, Ansible, AWS (EC2, VPC, EFS, S3, ALB, ASG, CloudWatch), Jenkins

**Outcomes:**
- **70% reduction** in deployment time through Golden AMI automation
- **99.9% uptime** achieved with multi-AZ high availability architecture
- **35% cost savings** through S3 lifecycle policies and resource optimization
- **Zero-downtime deployments** enabled via rolling updates and health checks

---

### Enterprise DevSecOps CI/CD Pipeline

**Objective:** Implemented a production-grade DevSecOps pipeline with integrated security scanning, quality gates, and automated containerization workflows.

**Key Achievements:**
- Built comprehensive Jenkins pipeline with 9 stages: Build, Unit Test, Code Coverage, SCA, SAST, Quality Gates, Container Build, Image Scanning, and Deployment
- Integrated security tools: Trivy (container scanning), OWASP Dependency-Check (SCA), SonarQube (SAST), and SpotBugs
- Implemented automated quality gates with code coverage thresholds and security policy enforcement
- Configured automated notifications and reporting for pipeline status and security findings
- Enabled containerized application delivery with Docker image building and scanning

**Technologies:** Jenkins, Groovy, Docker, Trivy, OWASP Dependency-Check, SonarQube, Maven, JaCoCo

**Outcomes:**
- **100% security scan coverage** for all containerized applications
- **Automated quality gates** preventing vulnerable code from reaching production
- **Reduced security vulnerabilities** by 60% through early detection in CI/CD pipeline

---

### Infrastructure as Code Automation Framework

**Objective:** Developed reusable Terraform modules and Ansible playbooks for standardized, repeatable infrastructure provisioning and configuration management.

**Key Achievements:**
- Created modular Terraform architecture with separate modules for VPC, EFS, ELB, and ASG
- Built Ansible roles for security hardening, OS updates, and application configuration
- Implemented state management with S3 backend and versioning
- Automated infrastructure validation and testing workflows

**Technologies:** Terraform, Ansible, AWS, Git, S3

**Outcomes:**
- **85% reduction** in configuration errors through standardized modules
- **60% faster** infrastructure provisioning compared to manual setup
- **Consistent deployments** across development, staging, and production environments

---

## CERTIFICATIONS

- AWS Certified Solutions Architect – Associate
- HashiCorp Certified: Terraform Associate
- ISTQB Advanced Test Automation Engineer
- Global Public Sector Security Certification
- Agile with Atlassian Jira Certified
- Certified Kubernetes Administrator (CKA) – In Progress

---

## EDUCATION

**Bachelor's Degree in [Your Field]**  
*University Name – Graduation Year*

---

## ADDITIONAL INFORMATION

- **Technical Blog:** [Your Medium/Blog URL]
- **GitHub:** [Your GitHub URL]
- **LinkedIn:** [Your LinkedIn URL]

---

