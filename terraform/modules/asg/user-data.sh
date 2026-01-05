#!/bin/bash
set -e

# Mount EFS
EFS_ID="${efs_id}"
EFS_DNS_NAME="${efs_dns_name}"
MOUNT_POINT="${mount_point}"

# Install EFS utilities if not already installed
# EFS utils should already be installed in the AMI, but ensure it's available
if ! command -v mount.efs &> /dev/null; then
    apt-get update -y
    apt-get install -y binutils
    git clone https://github.com/aws/efs-utils /tmp/efs-utils
    cd /tmp/efs-utils
    ./build-deb.sh
    apt-get install -y ./build/amazon-efs-utils*.deb
    cd /
    rm -rf /tmp/efs-utils
fi

# Create mount point
mkdir -p $${MOUNT_POINT}

# Mount EFS
echo "$${EFS_DNS_NAME}:/ $${MOUNT_POINT} efs defaults,_netdev,tls,iam 0 0" >> /etc/fstab
mount -a

# Set proper permissions
chown -R jenkins:jenkins $${MOUNT_POINT}
chmod 755 $${MOUNT_POINT}

# Configure Jenkins for HA
JENKINS_HOME="$${MOUNT_POINT}"
# On Ubuntu, Jenkins config is in /etc/default/jenkins instead of /etc/sysconfig/jenkins
JENKINS_CONFIG="/etc/default/jenkins"

# Update Jenkins configuration (Ubuntu uses different format)
if [ -f "$${JENKINS_CONFIG}" ]; then
    sed -i "s|JENKINS_HOME=.*|JENKINS_HOME=$${JENKINS_HOME}|g" $${JENKINS_CONFIG}
    
    # Configure Jenkins to use EFS for shared workspace
    if ! grep -q "JENKINS_JAVA_OPTIONS" $${JENKINS_CONFIG}; then
        echo "" >> $${JENKINS_CONFIG}
        echo "# HA Configuration" >> $${JENKINS_CONFIG}
        echo "JENKINS_JAVA_OPTIONS=\"-Djava.awt.headless=true -Xmx2048m -Xms512m -Dhudson.model.DirectoryBrowserSupport.CSP= -Djenkins.install.runSetupWizard=false\"" >> $${JENKINS_CONFIG}
    fi
fi

# Create Jenkins init script for HA setup
cat > /opt/jenkins/init-scripts/ha-setup.sh << 'EOF'
#!/bin/bash
# Wait for Jenkins to be ready
until curl -f http://localhost:8080/login 2>/dev/null; do
  echo "Waiting for Jenkins to start..."
  sleep 10
done

# Configure Jenkins for HA (if not already configured)
# This script runs on first instance only
EOF

chmod +x /opt/jenkins/init-scripts/ha-setup.sh
chown jenkins:jenkins /opt/jenkins/init-scripts/ha-setup.sh

# Start Jenkins
systemctl start jenkins
systemctl enable jenkins

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "metrics": {
    "namespace": "Jenkins/HA",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/jenkins/jenkins.log",
            "log_group_name": "/aws/jenkins/ha",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

systemctl start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent

# Log completion
echo "Jenkins HA setup completed at $(date)" >> /var/log/jenkins-ha-setup.log

