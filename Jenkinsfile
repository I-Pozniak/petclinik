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
            dir("${env.TF_DIR}") {
                sh "terraform init -no-color"

                // 1. Отримуємо весь вивід у форматі JSON
                def tfOutputJson = sh(script: "terraform output -json", returnStdout: true).trim()

                // 2. Парсимо JSON за допомогою JsonSlurper
                def props = new groovy.json.JsonSlurper().parseText(tfOutputJson)

                // 3. Зчитуємо значення (зверни увагу на .value)
                // Якщо назва в Terraform "aws_region", дістаємо її так:
                env.AWS_REGION = props.aws_region?.value
                env.ECR_URL    = props.ecr_repository_url?.value
                env.EC2_IP     = props.ec2_public_ip?.value

                // Перевірка на null
                if (!env.AWS_REGION) {
                    error "❌ Ключ 'aws_region' не знайдено в Terraform output! Доступні ключі: ${props.keySet()}"
                }

                echo "✅ Витягнуто з JSON: Region=${env.AWS_REGION}"
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
                    echo "🐳 Pushing Docker image to ECR..."
                    echo "Region: ${env.AWS_REGION}"
                    echo "ECR URL: ${env.ECR_URL}"

                    // Extract registry URL (everything before the last /)
                    def ecrRegistry = env.ECR_URL.split('/')[0]
                    echo "ECR Registry: ${ecrRegistry}"

                    // Login to ECR
                    sh """
                        aws ecr get-login-password --region ${env.AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ecrRegistry}
                    """

                    // Build and tag Docker image
                    sh "docker build -t ${env.ECR_URL}:latest -t ${env.ECR_URL}:${env.BUILD_NUMBER} ."

                    // Push both tags
                    sh "docker push ${env.ECR_URL}:latest"
                    sh "docker push ${env.ECR_URL}:${env.BUILD_NUMBER}"

                    echo "✅ Docker images pushed successfully"
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