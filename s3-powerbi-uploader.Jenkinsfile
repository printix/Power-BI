@Library('jenkins-shared-lib')_

pipeline {

    agent {
        node {
            label 'built-in'
        }
    }

    parameters {
        string(name: 'TEMPLATE_VERSION', defaultValue: '', description: 'Template version')
    }
    
    options {
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Release') {
            environment {
                GH_TOKEN = credentials('printix-automation-github-cli-personal-access-token')
            }
            steps {
                withTools('TOOL_GITHUB_CLI') {
                    sh """
                        gh release list
                        gh release create ${params.TEMPLATE_VERSION} -n \"Release notes\" --target master -t ${params.TEMPLATE_VERSION}
                        gh release upload ${params.TEMPLATE_VERSION} --clobber PowerBI/printix.pbit
                    """
                }
            }
        }

        stage('Upload') {
            environment {
                AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_DEFAULT_REGION = "eu-west-1"
            }
            steps {
                withTools('TOOL_AWS_CLI') {
                    sh """
                        aws s3 cp PowerBI/printix.pbit s3://printix-software/powerbi/${params.TEMPLATE_VERSION}/printix-${params.TEMPLATE_VERSION}.pbit
                    """
                }
            }
        }
    }
}
