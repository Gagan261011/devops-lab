// Jenkins Job DSL script to create CI/CD pipeline job
// This is automatically executed by Jenkins Configuration as Code

pipelineJob('java-crud-ci-cd') {
    description('Full CI/CD pipeline for Java CRUD application with build, test, SonarQube analysis, Nexus publish, and Ansible deployment')
    
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('GITHUB_REPO_PLACEHOLDER')
                    }
                    branches('*/main', '*/master')
                }
            }
            scriptPath('jenkins/Jenkinsfile')
            lightweight(true)
        }
    }
    
    properties {
        disableConcurrentBuilds()
        buildDiscarder {
            strategy {
                logRotator {
                    numToKeepStr('10')
                    daysToKeepStr('30')
                }
            }
        }
    }
    
    triggers {
        pollSCM {
            scmpoll_spec('H/5 * * * *')
        }
    }
    
    parameters {
        stringParam('DEPLOY_ENV', 'production', 'Deployment environment')
        booleanParam('SKIP_TESTS', false, 'Skip unit tests')
        booleanParam('SKIP_SONAR', false, 'Skip SonarQube analysis')
    }
}
