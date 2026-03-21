variable "project_name" {
  type        = string
  description = "Name of the project for tagging resources"
  default     = "petclinic"
}


variable "account_id" {
  type        = string
  description = "AWS Account ID"
}

variable "region" {
  type        = string
  description = "AWS Region"
}

variable "db_name" {
  type        = string
  description = "Name of the database"

}

variable "db_username" {
  type        = string
  description = "Username for the database"
}

variable "db_password" {
  type        = string
  description = "Password for the database"
}

variable "key_name" {
  type        = string
  description = "Name of the EC2 key pair for SSH access"
}

variable "jenkins_ingress_ip" {
  description = "IP address or CIDR block allowed to access Jenkins"
  type        = string

  validation {
    condition     = can(cidrhost(var.jenkins_ingress_ip, 0))
    error_message = "jenkins_ingress_ip must be a valid CIDR block, for example 195.82.150.40/32."
  }
}