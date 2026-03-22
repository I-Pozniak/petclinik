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

                // 1. Отримуємо JSON
                def tfOutputJson = sh(script: "terraform output -json", returnStdout: true).trim()

                // ДЕБАГ: виводимо весь JSON, щоб побачити структуру (це з'явиться в логах)
                println "DEBUG JSON: ${tfOutputJson}"

                def props = new groovy.json.JsonSlurper().parseText(tfOutputJson)

                // 2. Використовуємо безпечне отримання через Map.get()
                // Це виключає помилки, якщо об'єкт раптом має іншу структуру
                def regionObj = props.get('aws_region')
                def ecrObj    = props.get('ecr_repository_url')
                def ipObj     = props.get('ec2_public_ip')

                // 3. Присвоюємо значення (важливо: примусово перетворюємо на String)
                env.AWS_REGION = regionObj?.value?.toString()
                env.ECR_URL    = ecrObj?.value?.toString()
                env.EC2_IP     = ipObj?.value?.toString()

                // 4. Фінальна перевірка
                if (env.AWS_REGION == null || env.AWS_REGION == "null" || env.AWS_REGION == "") {
                    // Якщо впаде тут, ми побачимо, що саме було в об'єкті
                    error "❌ Значення для 'aws_region' порожнє! Вміст об'єкта: ${regionObj}"
                }

                echo "✅ Вдалося! Регіон: ${env.AWS_REGION}, ECR: ${env.ECR_URL}"
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