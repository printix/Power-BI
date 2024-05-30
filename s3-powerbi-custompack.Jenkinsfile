@Library('jenkins-shared-lib')_

pipeline {

    agent {
        node {
            label 'built-in'
        }
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
                ZIP_FILE_NAME="PowerBITemplateCustomizationPack.zip"
            }
            steps {
                buildDescription("""
                      Power BI template customization pack
                """)

                zip(dir: ".", glob: "Fonts/**/*.*, Images/**/*.*, PowerPoint/**/*.*, Themes/**/*.*", zipFile: env.ZIP_FILE_NAME, overwrite: true)
                
                withTools('TOOL_AWS_CLI') {
                    sh """                                
                        aws s3 cp $ZIP_FILE_NAME s3://printix-software/template/powerbi/custompack/$ZIP_FILE_NAME
                    """
                }
            }
        }
    }
}
