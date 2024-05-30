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
       
        stage('Upload_powerBi_template_customization_pack') {
            environment {
                AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_DEFAULT_REGION = "eu-west-1"
                ROOT = "custompack"                
                ZIP_FILE_NAME="PowerBITemplateCustomizationPack.zip"
            }
            steps {
                buildDescription("""
                      Power BI template customization pack
                """)
                
                fileOperations([
                    fileCopyOperation(
                        includes: "Fonts",
                        targetLocation: env.ROOT,
                        flattenFiles: false),
                    fileCopyOperation(
                        includes: "Images",
                        targetLocation: env.ROOT,
                        flattenFiles: false),
                    fileCopyOperation(
                        includes: "PowerPoint",
                        targetLocation: env.ROOT,
                        flattenFiles: false),
                    fileCopyOperation(
                        includes: "Themes",
                        targetLocation: env.ROOT,
                        flattenFiles: false),
                ])
                
                zip(dir: ".", glob: "**/${ROOT}/*", zipFile: env.ZIP_FILE_NAME)
                
                withTools('TOOL_AWS_CLI') {
                    sh """                                
                        aws s3 cp $ZIP_FILE_NAME s3://printix-software/template/powerbi/custompack/$ZIP_FILE_NAME
                    """
                }
            }
        }
    }
}
