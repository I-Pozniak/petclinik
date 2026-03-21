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


        AWS_REGION = ""
        EC2_IP     = ""
        ECR_URL    = ""
        ALB_URL    = ""
    }

    stages {
        stage('Extract Cloud Params') {
            steps {
                script {
                    echo "📡 Отримуємо параметри з Terraform..."
                    dir("${env.TF_DIR}") {
                        sh "terraform init -no-color"
                        env.AWS_REGION = sh(script: "terraform output -raw aws_region", returnStdout: true).trim()
                        env.EC2_IP     = sh(script: "terraform output -raw ec2_public_ip", returnStdout: true).trim()
                        env.ECR_URL    = sh(script: "terraform output -raw ecr_repository_url", returnStdout: true).trim()
                        env.ALB_URL    = sh(script: "terraform output -raw alb_dns_name", returnStdout: true).trim()
                    }
                }
            }
        }

        stage('Build Artifact') {
            steps {

                sh "mvn -f petclinic-app/pom.xml clean install -DskipTests"
            }
        }

        stage('Docker Push to ECR') {
            steps {
                script {

                    sh "aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${env.ECR_URL}"

                    sh "docker build -t ${env.ECR_URL}:latest -t ${env.ECR_URL}:${env.BUILD_NUMBER} ."
                    sh "docker push ${env.ECR_URL}:latest"
                    sh "docker push ${env.ECR_URL}:${env.BUILD_NUMBER}"
                }
            }
        }

        stage('Deploy to App Server') {
            steps {

                sshagent(['petclinic-ssh-key']) {
                    script {
                        echo "🚚 Деплоїмо на ${env.EC2_IP}..."


                        sh "scp -o StrictHostKeyChecking=no deploy/docker-compose.yml ec2-user@${env.EC2_IP}:/opt/petclinic/"


                        sh """
                        ssh -o StrictHostKeyChecking=no ec2-user@${env.EC2_IP} << 'EOF'
                            cd /opt/petclinic
                            aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${env.ECR_URL.split('/')[0]}
                            export ECR_REPO_URL=${env.ECR_URL}
                            docker compose pull
                            docker compose up -d
                        EOF
                        """
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
            -d text="✅ *PetClinic успішно оновлено!*%0A%0A🌍 *Регіон:* ${env.AWS_REGION}%0A🚀 *URL:* http://${env.ALB_URL}%0A📦 *Збірка:* #${env.BUILD_NUMBER}" \
            -d parse_mode="Markdown"
            """
        }
        failure {
            sh "curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage -d chat_id=$TELEGRAM_CHAT_ID -d text='❌ Помилка деплою PetClinic #$BUILD_NUMBER'"
        }
    }
}