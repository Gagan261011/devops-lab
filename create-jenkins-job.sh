#!/bin/bash
# Create Jenkins job using Job DSL

set -e

echo "Creating Jenkins pipeline job..."

# Wait for Jenkins to be ready
sleep 10

# Create job config XML
cat > /tmp/job-config.xml << 'XMLEOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Full CI/CD pipeline for Java CRUD application</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.DisableConcurrentBuildsJobProperty/>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/Gagan261011/devops-lab.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
        <hudson.plugins.git.BranchSpec>
          <name>*/master</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>jenkins/Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
XMLEOF

# Copy to Jenkins jobs directory
sudo mkdir -p /var/lib/jenkins/jobs/java-crud-ci-cd
sudo cp /tmp/job-config.xml /var/lib/jenkins/jobs/java-crud-ci-cd/config.xml
sudo chown -R jenkins:jenkins /var/lib/jenkins/jobs/java-crud-ci-cd

# Reload Jenkins configuration
sudo systemctl reload jenkins || sudo systemctl restart jenkins

echo "Job created successfully!"
echo "Job name: java-crud-ci-cd"
