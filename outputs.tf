output "vpc_id" {
  description = "The ID of the newly created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_az1_id" {
  description = "ID of the public subnet in AZ1"
  value       = module.vpc.public_subnet_ids[0]
}

output "private_subnet_az1_id" {
  description = "ID of the private subnet in AZ1"
  value       = module.vpc.private_subnet_ids[0]
}

output "private_subnet_az2_id" {
  description = "ID of the private subnet in AZ2"
  value       = module.vpc.private_subnet_ids[1]
}

output "bastion_public_ip" {
  description = "The public IP address of the Bastion Host"
  value       = module.bastion.bastion_public_ip
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "The name of the ECS service"
  value       = module.ecs.service_name
}

output "ecs_fargate_sg_id" {
  description = "The ID of the ECS Fargate Security Group"
  value       = module.security_groups.ecs_fargate_sg_id
}

output "rds_endpoint" {
  description = "Endpoint for the RDS PostgreSQL database"
  value       = module.rds.rds_endpoint
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for Docker images"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository for Docker images"
  value       = module.ecr.repository_name
}

output "db_init_task_definition_arn" {
  description = "ARN of the Fargate task definition for DB initialization"
  value       = module.ecs.db_init_task_definition_arn
}

output "db_init_task_role_arn" {
  description = "ARN of the IAM role for the DB initialization Fargate task"
  value       = module.ecs.db_init_task_role_arn
}