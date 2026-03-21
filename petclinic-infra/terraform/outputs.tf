output "ec2_public_ip" {
  description = "Public IP of the App Server"
  value       = module.compute.ec2_public_ip
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = module.compute.ecr_repository_url
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.compute.alb_dns_name
}

output "rds_endpoint" {
  description = "The connection endpoint for RDS"
  value       = module.database.rds_endpoint
}

output "aws_region" {
  description = "The AWS region where resources are deployed"
  value       = var.region
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins Master"
  value       = module.compute.jenkins_public_ip
}
