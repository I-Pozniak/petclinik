variable "project_name" {
  description = "Name of the project for tagging resources"
  type        = string
}
variable "vpc_id" {
  description = "ID of the VPC to use for security group"
  type        = string
}
variable "public_subnet_ids" {
  description = "List of public subnet IDs for the compute resources"
  type        = list(string)
}
variable "app_sg_id" {
  description = "ID of the security group for the application"
  type        = string
}
variable "alb_sg_id" {
  description = "ID of the security group for the ALB"
  type        = string
}
variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}
variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  type        = string
}

variable "jenkins_ingress_ip" {
  description = "IP address or CIDR block allowed to access Jenkins"
  type        = string
}