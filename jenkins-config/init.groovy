// Jenkins Initialization Script for HA Setup
// This script runs on Jenkins startup to configure HA settings

import jenkins.model.*
import hudson.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

// Configure Jenkins for HA
println "Configuring Jenkins for High Availability..."

// Set number of executors
instance.setNumExecutors(2)

// Configure workspace directory (should be on EFS)
def workspaceDir = System.getenv("JENKINS_HOME") + "/workspace"
println "Workspace directory: ${workspaceDir}"

// Save configuration
instance.save()

println "Jenkins HA configuration completed."

