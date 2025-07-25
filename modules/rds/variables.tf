variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "The ID of the RDS security group"
  type        = string
}

variable "db_master_username" {
  description = "Master username for the RDS PostgreSQL database"
  type        = string
}

variable "db_master_password" {
  description = "Master password for the RDS PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
}

variable "aws_account_id" {
  description = "The AWS account ID"
  type        = string
}
