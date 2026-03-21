variable "vpc_id" {
  type        = string
  description = "ID of the VPC to use for security group"
}


variable "project_name" {
  type        = string
  description = "Name of the project for tagging resources"
  default     = "petclinic"
}


variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the database"
}

variable "mysql_db_sg_id" {
  type        = string
  description = "ID of the security group for the MySQL database"
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