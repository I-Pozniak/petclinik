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
                        // Initialize terraform with backend configuration
                        sh "terraform init -no-color -input=false -reconfigure"

                        // Extract outputs with error handling
                        env.AWS_REGION = sh(script: "terraform output -raw aws_region", returnStdout: true).trim()
                        env.EC2_IP     = sh(script: "terraform output -raw ec2_public_ip", returnStdout: true).trim()
                        env.ECR_URL    = sh(script: "terraform output -raw ecr_repository_url", returnStdout: true).trim()
                        env.ALB_URL    = sh(script: "terraform output -raw alb_dns_name 2>/dev/null || echo 'N/A'", returnStdout: true).trim()

                        echo "✅ AWS Region: ${env.AWS_REGION}"
                        echo "✅ EC2 IP: ${env.EC2_IP}"
                        echo "✅ ECR URL: ${env.ECR_URL}"
                        echo "✅ ALB URL: ${env.ALB_URL}"

                        // Validate required parameters
                        if (!env.AWS_REGION || env.AWS_REGION == '' || env.AWS_REGION == 'null') {
                            error("❌ Failed to extract AWS_REGION from Terraform outputs")
                        }
                        if (!env.ECR_URL || env.ECR_URL == '' || env.ECR_URL == 'null') {
                            error("❌ Failed to extract ECR_URL from Terraform outputs")
                        }
                        if (!env.EC2_IP || env.EC2_IP == '' || env.EC2_IP == 'null') {
                            error("❌ Failed to extract EC2_IP from Terraform outputs")
                        }
                    }
                }
            }
        }
        stage('System & Terraform Debug') {
    steps {
        script {
            // Navigate to the directory where Terraform files are located
            dir("${env.TF_DIR}") {
                sh '''
                    echo "--- 1. IDENTITY CHECK ---"
                    # Check which user is executing the process (should be 'jenkins')
                    whoami && id

                    echo "--- 2. ENVIRONMENT CHECK ---"
                    # Verify the current working directory path
                    pwd

                    echo "--- 3. PERMISSION CHECK ---"
                    # List all files, including hidden ones, to check ownership (User/Group)
                    ls -la

                    echo "--- 4. TERRAFORM INITIALIZATION ---"
                    # Try to initialize. If it fails, we want to see the error, not stop the build yet.
                    # -input=false prevents the process from hanging if it asks for a prompt.
                    terraform init -no-color -input=false || echo "Terraform Init failed!"

                    echo "--- 5. CLOUD CONNECTIVITY CHECK ---"
                    # Try to pull data from the S3 Backend.
                    # If this fails with 403, the IAM Role on the EC2 is missing S3 permissions.
                    terraform output -no-color || echo "Failed to fetch outputs from S3!"
                '''
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