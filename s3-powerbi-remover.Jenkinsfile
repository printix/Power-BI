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
         stage('Delete') {
            environment {
                AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_DEFAULT_REGION = "eu-west-1"
            }
            steps {
                buildDescription("""
                      printix-${params.TEMPLATE_VERSION}.pbit
                """)
                withTools('TOOL_AWS_CLI') {
                    sh """
                        aws s3 rm s3://printix-software/powerbi/${params.TEMPLATE_VERSION}/printix-${params.TEMPLATE_VERSION}.pbit
                    """
                }
            }
        }
    }
}
