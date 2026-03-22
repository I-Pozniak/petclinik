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
                        // Check AWS credentials first
                        echo "=== Checking AWS Credentials ==="
                        sh "aws sts get-caller-identity"

                        // Initialize terraform with backend configuration
                        echo "=== Initializing Terraform ==="
                        sh "terraform init -no-color -input=false -reconfigure"

                        // Verify state file exists
                        echo "=== Checking Terraform State ==="
                        def stateCheck = sh(script: "terraform state list 2>&1 | head -5", returnStdout: true).trim()
                        echo "State preview: ${stateCheck}"

                        if (stateCheck.contains("No state file was found") || stateCheck.contains("Error")) {
                            error("❌ Terraform state is not available. Please run 'terraform apply' first.")
                        }

                        // First, let's see what outputs are available
                        echo "=== Available Terraform Outputs ==="
                        sh "terraform output -no-color"

                        // Try JSON output first for better parsing
                        echo "=== Extracting Outputs via JSON ==="
                        def outputsJson = sh(script: "terraform output -json", returnStdout: true).trim()
                        echo "JSON Outputs: ${outputsJson}"

                        // Parse JSON to extract values
                        def outputs = readJSON text: outputsJson

                        def awsRegion = outputs.aws_region?.value ?: ''
                        def ec2Ip = outputs.ec2_public_ip?.value ?: ''
                        def ecrUrl = outputs.ecr_repository_url?.value ?: ''
                        def albUrl = outputs.alb_dns_name?.value ?: 'N/A'

                        echo "Parsed AWS Region: [${awsRegion}]"
                        echo "Parsed EC2 IP: [${ec2Ip}]"
                        echo "Parsed ECR URL: [${ecrUrl}]"
                        echo "Parsed ALB URL: [${albUrl}]"

                        // Validate extracted values
                        if (!awsRegion || awsRegion == '') {
                            error("❌ Failed to extract AWS_REGION from outputs")
                        }
                        if (!ec2Ip || ec2Ip == '') {
                            error("❌ Failed to extract EC2_IP from outputs")
                        }
                        if (!ecrUrl || ecrUrl == '') {
                            error("❌ Failed to extract ECR_URL from outputs")
                        }

                        // Assign to environment variables
                        env.AWS_REGION = awsRegion
                        env.EC2_IP = ec2Ip
                        env.ECR_URL = ecrUrl
                        env.ALB_URL = albUrl

                        echo "✅ AWS Region: ${env.AWS_REGION}"
                        echo "✅ EC2 IP: ${env.EC2_IP}"
                        echo "✅ ECR URL: ${env.ECR_URL}"
                        echo "✅ ALB URL: ${env.ALB_URL}"
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