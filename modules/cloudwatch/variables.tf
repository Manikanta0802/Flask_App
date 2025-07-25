variable "alb_id" {
  description = "The ID of the Application Load Balancer"
  type        = string
}

variable "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "The name of the ECS service"
  type        = string
}

variable "rds_instance_id" {
  description = "Identifier of the RDS instance"
  type        = string
}

variable "log_group_name" {
  description = "Name of the ECS application log group"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
}