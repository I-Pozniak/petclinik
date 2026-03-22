pipeline {
    agent any

    tools {
        maven 'Maven'
        terraform 'Terraform'
    }

    environment {
        TF_DIR = 'petclinic-infra/terraform'

        TELEGRAM_TOKEN   = credentials('telegram_token')
        TELEGRAM_CHAT_ID = credentials('telegram_chat_id')

        TF_AWS_REGION = credentials('TF_AWS_REGION')
        TF_ECR_URL    = credentials('TF_ECR_URL')
        TF_EC2_IP     = credentials('TF_EC2_IP')
        TF_ALB_URL    = credentials('TF_ALB_URL')
    }

    stages {
//        stage('Extract Cloud Params') {
//            steps {
//                script {
//                    dir("${env.TF_DIR}") {
//                        sh "terraform init -no-color"
//
//                        def tfOutputJson = sh(
//                            script: "terraform output -json",
//                            returnStdout: true
//                        ).trim()
//
//                        def props = new groovy.json.JsonSlurperClassic().parseText(tfOutputJson)
//
//                        def readTfOutput = { Map outputMap, String key ->
//                            def item = outputMap[key]
//                            if (item == null) {
//                                return ''
//                            }
//                            def rawValue = (item instanceof Map && item.containsKey('value')) ? item['value'] : item
//                            return rawValue == null ? '' : rawValue.toString().trim()
//                        }
//
//                        env.TF_AWS_REGION = readTfOutput(props, 'aws_region')
//                        env.TF_ECR_URL    = props.ecr_repository_url?.value?.toString()?.trim()
//                        env.TF_EC2_IP     = props.ec2_public_ip?.value?.toString()?.trim()
//                        env.TF_ALB_URL    = props.alb_dns_name?.value?.toString()?.trim()
//
//                        if (!env.TF_AWS_REGION) {
//                            error("Terraform output 'aws_region' is empty")
//                        }
//                        if (!env.TF_ECR_URL) {
//                            error("Terraform output 'ecr_repository_url' is empty")
//                        }
//                        if (!env.TF_EC2_IP) {
//                            error("Terraform output 'ec2_public_ip' is empty")
//                        }
//                        if (!env.TF_ALB_URL) {
//                            error("Terraform output 'alb_dns_name' is empty")
//                        }
//
//                        echo "Cloud parameters loaded: Region=${env.TF_AWS_REGION}, ECR=${env.TF_ECR_URL}, EC2=${env.TF_EC2_IP}, ALB=${env.TF_ALB_URL}"
//                    }
//                }
//            }
//        }

        stage('Build Artifact') {
            steps {
                sh "mvn -f petclinic-app/pom.xml clean install -DskipTests"
            }
        }

        stage('Docker Build & Push') {
            steps {
                script {
                    echo "Pushing Docker image to ECR..."
                    echo "Region: ${env.TF_AWS_REGION}"
                    echo "ECR URL: ${env.TF_ECR_URL}"

                    def ecrRegistry = env.TF_ECR_URL.split('/')[0]
                    echo "ECR Registry: ${ecrRegistry}"

                    sh """
                        aws ecr get-login-password --region ${env.TF_AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ecrRegistry}
                    """

                    sh """
                        docker build \
                          -t ${env.TF_ECR_URL}:latest \
                          -t ${env.TF_ECR_URL}:${env.BUILD_NUMBER} \
                          .
                    """

                    sh "docker push ${env.TF_ECR_URL}:latest"
                    sh "docker push ${env.TF_ECR_URL}:${env.BUILD_NUMBER}"

                    echo "Docker images pushed successfully"
                }
            }
        }

        stage('Deploy to App Server') {
            steps {
                sshagent(['web']) {
                    script {
                        echo "Deploying to ${env.TF_EC2_IP}..."

                        sh """
                            scp -o StrictHostKeyChecking=no \
                            deploy/docker-compose.yml \
                            ec2-user@${env.TF_EC2_IP}:/opt/petclinic/
                        """

                        def ecrRegistry = env.TF_ECR_URL.split('/')[0]

                        sh """
                            ssh -o StrictHostKeyChecking=no ec2-user@${env.TF_EC2_IP} << EOF
                                cd /opt/petclinic
                                aws ecr get-login-password --region ${env.TF_AWS_REGION} | docker login --username AWS --password-stdin ${ecrRegistry}
                                export ECR_REPO_URL=${env.TF_ECR_URL}
                                docker compose pull
                                docker compose up -d
                            EOF
                        """

                        echo "Deployment completed successfully"
                    }
                }
            }
        }
    }

    post {
        success {
            sh """
                curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage \
                -d chat_id=$TELEGRAM_CHAT_ID \
                -d text="✅ *PetClinic deployed successfully!*%0A%0A🌍 *Region:* ${env.TF_AWS_REGION}%0A🚀 *URL:* http://${env.TF_ALB_URL}%0A📦 *Build:* #${env.BUILD_NUMBER}" \
                -d parse_mode="Markdown"
            """
        }

        failure {
            sh """
                curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage \
                -d chat_id=$TELEGRAM_CHAT_ID \
                -d text="❌ PetClinic deployment failed. Build #${env.BUILD_NUMBER}"
            """
        }
    }
}