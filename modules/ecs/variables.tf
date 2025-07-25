variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_fargate_sg_id" {
  description = "The ID of the ECS Fargate security group"
  type        = string
}

variable "alb_tg_arn" {
  description = "The ARN of the ALB target group"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository"
  type        = string
}

variable "db_endpoint" {
  description = "Endpoint for the RDS PostgreSQL database"
  type        = string
}

variable "db_name" {
  description = "Name of the RDS database"
  type        = string
}

variable "db_port" {
  description = "Port of the RDS database"
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

variable "rds_instance_arn" {
  description = "ARN of the RDS instance"
  type        = string
}

variable "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret for DB credentials"
  type        = string
}