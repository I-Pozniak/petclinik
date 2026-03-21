variable "vpc_id" {
  type        = string
  description = "ID of the VPC to use for security group"
}


variable "project_name" {
  type        = string
  description = "Name of the project for tagging resources"
  default     = "petclinic"
}

