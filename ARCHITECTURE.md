# PetClinic Project - Architecture Diagram

## System Architecture Overview

```mermaid
graph TB
    subgraph "Developer Workspace"
        DEV[Developer]
        GIT[Git Repository]
    end

    subgraph "CI/CD Pipeline - Jenkins"
        JENKINS[Jenkins Server]
        MAVEN[Maven Build]
        DOCKER_BUILD[Docker Build]
        ECR_PUSH[Push to ECR]
        DEPLOY[Deploy Stage]
        TELEGRAM[Telegram Notifications]
    end

    subgraph "AWS Cloud Infrastructure"
        subgraph "VPC"
            subgraph "Public Subnets"
                ALB[Application Load Balancer<br/>Port 80]
                EC2[EC2 Instance<br/>Amazon Linux 2023<br/>t3.micro]
            end
            
            subgraph "Private Subnets"
                RDS[(RDS MySQL 8.0<br/>db.t3.micro)]
            end
        end
        
        ECR[AWS ECR<br/>Container Registry]
        SECRETS[AWS Secrets Manager<br/>DB Credentials]
        IAM[IAM Roles & Policies<br/>ECR Read, Secrets Access]
    end

    subgraph "Application Components on EC2"
        DOCKER_ENGINE[Docker Engine]
        COMPOSE[Docker Compose]
        PETCLINIC_CONTAINER[PetClinic Container<br/>Spring Boot App<br/>Port 8080]
    end

    subgraph "Infrastructure as Code"
        TERRAFORM[Terraform Modules]
        ANSIBLE[Ansible Playbooks]
        
        subgraph "Terraform Modules"
            TF_VPC[VPC Module]
            TF_SEC[Security Module]
            TF_DB[Database Module]
            TF_COMPUTE[Compute Module]
        end
        
        subgraph "Ansible Roles"
            AN_BASELINE[Baseline Role]
            AN_DOCKER[Docker Role]
            AN_SECRETS[Secrets Role]
            AN_APP[App Role]
        end
    end

    %% Development Flow
    DEV -->|Code Push| GIT
    GIT -->|Webhook Trigger| JENKINS

    %% CI/CD Pipeline Flow
    JENKINS -->|1. Build| MAVEN
    MAVEN -->|JAR Artifact| DOCKER_BUILD
    DOCKER_BUILD -->|2. Build Image| ECR_PUSH
    ECR_PUSH -->|3. Push Image| ECR
    JENKINS -->|4. Deploy| DEPLOY
    DEPLOY -->|SSH + Docker Compose| EC2
    JENKINS -->|Success/Failure| TELEGRAM

    %% Infrastructure Provisioning
    TERRAFORM -.->|Provisions| VPC
    TF_VPC -.->|Creates| ALB
    TF_VPC -.->|Creates| EC2
    TF_DB -.->|Creates| RDS
    TF_DB -.->|Stores Creds| SECRETS
    TF_SEC -.->|Configures| IAM
    TF_COMPUTE -.->|Creates| ECR

    ANSIBLE -.->|Configures| EC2
    AN_DOCKER -.->|Installs| DOCKER_ENGINE
    AN_SECRETS -.->|Fetches| SECRETS
    AN_APP -.->|Deploys| COMPOSE

    %% Runtime Flow
    ALB -->|Routes Traffic| EC2
    EC2 -->|Runs| DOCKER_ENGINE
    DOCKER_ENGINE -->|Manages| COMPOSE
    COMPOSE -->|Runs| PETCLINIC_CONTAINER
    PETCLINIC_CONTAINER -->|Connects| RDS
    EC2 -->|Pulls Image| ECR
    EC2 -->|Assumes| IAM
    IAM -->|Grants Access| ECR
    IAM -->|Grants Access| SECRETS
    EC2 -->|Retrieves Creds| SECRETS

    %% Styling
    classDef awsService fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:#232F3E
    classDef cicdService fill:#1E88E5,stroke:#0D47A1,stroke-width:2px,color:#fff
    classDef appService fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    classDef iacService fill:#9C27B0,stroke:#4A148C,stroke-width:2px,color:#fff
    classDef devService fill:#607D8B,stroke:#263238,stroke-width:2px,color:#fff

    class ALB,EC2,RDS,ECR,SECRETS,IAM awsService
    class JENKINS,MAVEN,DOCKER_BUILD,ECR_PUSH,DEPLOY,TELEGRAM cicdService
    class DOCKER_ENGINE,COMPOSE,PETCLINIC_CONTAINER appService
    class TERRAFORM,ANSIBLE,TF_VPC,TF_SEC,TF_DB,TF_COMPUTE,AN_BASELINE,AN_DOCKER,AN_SECRETS,AN_APP iacService
    class DEV,GIT devService
```

## Detailed Component Architecture

```mermaid
graph LR
    subgraph "Application Layer"
        USER[End User]
        BROWSER[Web Browser]
    end

    subgraph "AWS Network Layer"
        IGW[Internet Gateway]
        ALB[Application Load<br/>Balancer]
        TG[Target Group<br/>Port 8080]
    end

    subgraph "Compute Layer"
        EC2_INSTANCE[EC2 Instance]
        CONTAINER[PetClinic Container<br/>eclipse-temurin:17-jre-alpine<br/>Spring Boot + Thymeleaf]
    end

    subgraph "Data Layer"
        MYSQL[(MySQL 8.0 RDS<br/>petclinic DB)]
        SCHEMA[Schema: owners, pets,<br/>vets, visits, specialties]
    end

    subgraph "Security & Secrets"
        SG_ALB[Security Group: ALB<br/>Inbound: 80]
        SG_APP[Security Group: App<br/>Inbound: 8080, 22]
        SG_DB[Security Group: DB<br/>Inbound: 3306]
        SM[Secrets Manager<br/>DB Connection String]
    end

    USER -->|HTTPS/HTTP| BROWSER
    BROWSER -->|Port 80| IGW
    IGW --> ALB
    ALB -->|Health Check /| TG
    TG --> EC2_INSTANCE
    EC2_INSTANCE --> CONTAINER
    CONTAINER -->|JDBC Connection| MYSQL
    MYSQL --> SCHEMA

    SG_ALB -.->|Protects| ALB
    SG_APP -.->|Protects| EC2_INSTANCE
    SG_DB -.->|Protects| MYSQL
    CONTAINER -.->|Fetches| SM

    classDef userLayer fill:#B0BEC5,stroke:#546E7A,stroke-width:2px
    classDef networkLayer fill:#FF9900,stroke:#232F3E,stroke-width:2px
    classDef computeLayer fill:#4CAF50,stroke:#1B5E20,stroke-width:2px
    classDef dataLayer fill:#2196F3,stroke:#0D47A1,stroke-width:2px
    classDef securityLayer fill:#F44336,stroke:#B71C1C,stroke-width:2px

    class USER,BROWSER userLayer
    class IGW,ALB,TG networkLayer
    class EC2_INSTANCE,CONTAINER computeLayer
    class MYSQL,SCHEMA dataLayer
    class SG_ALB,SG_APP,SG_DB,SM securityLayer
```

## CI/CD Pipeline Flow

```mermaid
flowchart TD
    START([Developer Push])
    
    START --> TRIGGER{Jenkins<br/>Webhook}
    TRIGGER --> BUILD[Stage 1: Build Artifact<br/>mvn clean install]
    
    BUILD --> DOCKER[Stage 2: Docker Build & Push]
    DOCKER --> LOGIN[AWS ECR Login]
    LOGIN --> BUILD_IMG[Build Docker Image<br/>Tag: latest & build_number]
    BUILD_IMG --> PUSH[Push to ECR Registry]
    
    PUSH --> DEPLOY[Stage 3: Deploy to App Server]
    DEPLOY --> SSH[SSH to EC2 via SSHAgent]
    SSH --> PREP[Create /opt/petclinic directory]
    PREP --> COPY1[Copy app_secrets.env]
    COPY1 --> COPY2[Copy docker-compose.yml]
    COPY2 --> PULL[Pull Latest Image from ECR]
    PULL --> UP[Docker Compose Up -d]
    
    UP --> SUCCESS{Deployment<br/>Status}
    SUCCESS -->|Success| NOTIFY_OK[✅ Telegram Notification<br/>URL: http://ALB_DNS<br/>Build: #NUM]
    SUCCESS -->|Failure| NOTIFY_FAIL[❌ Telegram Notification<br/>Build Failed]
    
    NOTIFY_OK --> END([Deployment Complete])
    NOTIFY_FAIL --> END

    classDef processStep fill:#1E88E5,stroke:#0D47A1,stroke-width:2px,color:#fff
    classDef decisionStep fill:#FFA726,stroke:#E65100,stroke-width:2px,color:#fff
    classDef successStep fill:#66BB6A,stroke:#2E7D32,stroke-width:2px,color:#fff
    classDef failureStep fill:#EF5350,stroke:#C62828,stroke-width:2px,color:#fff

    class BUILD,DOCKER,LOGIN,BUILD_IMG,PUSH,DEPLOY,SSH,PREP,COPY1,COPY2,PULL,UP processStep
    class TRIGGER,SUCCESS decisionStep
    class NOTIFY_OK successStep
    class NOTIFY_FAIL failureStep
```

## Terraform Module Dependencies

```mermaid
graph TD
    MAIN[main.tf<br/>Root Module]
    
    MAIN --> VPC[VPC Module]
    MAIN --> SEC[Security Module]
    MAIN --> DB[Database Module]
    MAIN --> COMPUTE[Compute Module]
    
    VPC -->|vpc_id| SEC
    VPC -->|vpc_id| DB
    VPC -->|vpc_id| COMPUTE
    VPC -->|private_subnet_ids| DB
    VPC -->|public_subnet_ids| COMPUTE
    
    SEC -->|mysql_db_sg_id| DB
    SEC -->|app_sg_id| COMPUTE
    SEC -->|alb_sg_id| COMPUTE
    
    DB -->|db_secret_arn| COMPUTE
    
    subgraph "VPC Module Outputs"
        VPC_OUT1[vpc_id]
        VPC_OUT2[public_subnet_ids]
        VPC_OUT3[private_subnet_ids]
    end
    
    subgraph "Security Module Outputs"
        SEC_OUT1[app_sg_id]
        SEC_OUT2[mysql_db_sg_id]
        SEC_OUT3[alb_sg_id]
    end
    
    subgraph "Database Module Outputs"
        DB_OUT1[db_endpoint]
        DB_OUT2[db_secret_arn]
    end
    
    subgraph "Compute Module Outputs"
        COMP_OUT1[ec2_public_ip]
        COMP_OUT2[ecr_repository_url]
        COMP_OUT3[alb_dns_name]
    end

    VPC -.-> VPC_OUT1
    VPC -.-> VPC_OUT2
    VPC -.-> VPC_OUT3
    
    SEC -.-> SEC_OUT1
    SEC -.-> SEC_OUT2
    SEC -.-> SEC_OUT3
    
    DB -.-> DB_OUT1
    DB -.-> DB_OUT2
    
    COMPUTE -.-> COMP_OUT1
    COMPUTE -.-> COMP_OUT2
    COMPUTE -.-> COMP_OUT3

    classDef moduleStyle fill:#9C27B0,stroke:#4A148C,stroke-width:2px,color:#fff
    classDef outputStyle fill:#00BCD4,stroke:#006064,stroke-width:2px,color:#fff

    class MAIN,VPC,SEC,DB,COMPUTE moduleStyle
    class VPC_OUT1,VPC_OUT2,VPC_OUT3,SEC_OUT1,SEC_OUT2,SEC_OUT3,DB_OUT1,DB_OUT2,COMP_OUT1,COMP_OUT2,COMP_OUT3 outputStyle
```

## Ansible Deployment Workflow

```mermaid
flowchart TD
    START([Ansible Playbook: app.yml])
    
    START --> INVENTORY[Dynamic Inventory<br/>aws_ec2.yaml]
    INVENTORY --> TARGET[Target: aws_tag_petclinic_app_instance]
    
    TARGET --> BASELINE[Role: Baseline<br/>System Updates & Dependencies]
    BASELINE --> DOCKER_ROLE[Role: Docker<br/>Install Docker Engine & Compose]
    DOCKER_ROLE --> SECRETS[Role: Secrets<br/>Fetch DB Credentials from AWS]
    SECRETS --> APP[Role: App<br/>Deploy Application]
    
    APP --> CREATE_ENV[Create app_secrets.env]
    CREATE_ENV --> PULL_IMAGE[Pull Docker Image from ECR]
    PULL_IMAGE --> COMPOSE_UP[Run Docker Compose]
    COMPOSE_UP --> VERIFY[Verify Container Status]
    
    VERIFY --> END([Deployment Complete])

    classDef roleStyle fill:#673AB7,stroke:#311B92,stroke-width:2px,color:#fff
    classDef taskStyle fill:#3F51B5,stroke:#1A237E,stroke-width:2px,color:#fff

    class BASELINE,DOCKER_ROLE,SECRETS,APP roleStyle
    class INVENTORY,TARGET,CREATE_ENV,PULL_IMAGE,COMPOSE_UP,VERIFY taskStyle
```

## Data Flow Architecture

```mermaid
sequenceDiagram
    participant User
    participant ALB as Application Load Balancer
    participant EC2 as EC2 Instance
    participant Container as PetClinic Container
    participant RDS as MySQL RDS
    participant Secrets as AWS Secrets Manager

    Note over User,RDS: Application Startup Flow
    EC2->>Secrets: Fetch DB Credentials
    Secrets-->>EC2: Return DB Connection Details
    EC2->>Container: Start Container with Env Vars
    Container->>RDS: Initialize DB Connection Pool
    Container->>RDS: Execute schema.sql
    Container->>RDS: Execute data.sql
    RDS-->>Container: Schema & Data Ready
    Container->>Container: Spring Boot App Ready

    Note over User,RDS: User Request Flow
    User->>ALB: HTTP Request (Port 80)
    ALB->>ALB: Health Check /
    ALB->>EC2: Forward to Target (Port 8080)
    EC2->>Container: Route to PetClinic App
    Container->>Container: Process with Spring MVC
    Container->>RDS: Query: SELECT * FROM owners
    RDS-->>Container: Return Owner Data
    Container->>Container: Render Thymeleaf Template
    Container-->>EC2: HTML Response
    EC2-->>ALB: Return Response
    ALB-->>User: Serve Web Page

    Note over User,RDS: CI/CD Deployment Flow
    activate Container
    Container->>Container: Graceful Shutdown
    EC2->>Container: Stop Old Container
    deactivate Container
    EC2->>ECR: Pull New Image
    EC2->>Container: Start New Container
    activate Container
    Container->>Secrets: Fetch DB Credentials
    Container->>RDS: Reconnect to Database
    Container->>Container: Application Ready
```

## Security Architecture

```mermaid
graph TB
    subgraph "Internet"
        PUBLIC[Public Users]
        JENKINS_EXT[Jenkins CI/CD]
    end

    subgraph "AWS VPC"
        subgraph "Public Subnet"
            ALB[ALB<br/>SG: Allow 80/443]
            EC2[EC2 Instance<br/>SG: Allow 8080 from ALB<br/>Allow 22 from Jenkins IP]
        end
        
        subgraph "Private Subnet"
            RDS[RDS MySQL<br/>SG: Allow 3306 from App SG]
        end
        
        subgraph "Security Services"
            IAM_ROLE[IAM Role<br/>EC2 Instance Profile]
            SECRETS_MGR[Secrets Manager<br/>DB Credentials Encrypted]
            ECR_REG[ECR Registry<br/>Private Repository]
        end
    end

    PUBLIC -->|Port 80/443| ALB
    JENKINS_EXT -->|SSH Port 22| EC2
    ALB -->|Port 8080| EC2
    EC2 -->|Port 3306| RDS
    
    EC2 -.->|AssumeRole| IAM_ROLE
    IAM_ROLE -.->|Read Policy| ECR_REG
    IAM_ROLE -.->|GetSecretValue| SECRETS_MGR
    
    EC2 -.->|Pull Images| ECR_REG
    EC2 -.->|Fetch Credentials| SECRETS_MGR

    classDef publicZone fill:#FFCDD2,stroke:#C62828,stroke-width:2px
    classDef computeZone fill:#C8E6C9,stroke:#2E7D32,stroke-width:2px
    classDef dataZone fill:#BBDEFB,stroke:#1565C0,stroke-width:2px
    classDef securityZone fill:#FFF9C4,stroke:#F57F17,stroke-width:2px

    class PUBLIC,JENKINS_EXT publicZone
    class ALB,EC2 computeZone
    class RDS dataZone
    class IAM_ROLE,SECRETS_MGR,ECR_REG securityZone
```

## Technology Stack Summary

### Infrastructure Layer
- **Cloud Provider**: AWS
- **IaC Tool**: Terraform (Modular Architecture)
- **Configuration Management**: Ansible
- **Compute**: EC2 t3.micro (Amazon Linux 2023)
- **Container Registry**: AWS ECR
- **Load Balancer**: Application Load Balancer (ALB)

### Database Layer
- **Database**: MySQL 8.0 on RDS (db.t3.micro)
- **Deployment**: Private subnet with DB subnet group
- **Security**: AWS Secrets Manager for credentials

### Application Layer
- **Framework**: Spring Boot 3.x
- **Language**: Java 17
- **Build Tool**: Maven
- **Template Engine**: Thymeleaf
- **Container**: Docker (eclipse-temurin:17-jre-alpine)
- **Orchestration**: Docker Compose

### CI/CD Layer
- **CI/CD Tool**: Jenkins
- **Build**: Maven
- **Containerization**: Docker
- **Deployment**: SSH + Docker Compose
- **Notifications**: Telegram Bot API

### Security Layer
- **Authentication**: IAM Roles & Instance Profiles
- **Secrets Management**: AWS Secrets Manager
- **Network Security**: VPC Security Groups
- **Access Control**: SSH Key-based authentication

### Monitoring & Logging
- **CloudWatch**: EC2 and RDS monitoring
- **Health Checks**: ALB health check on root path (/)


