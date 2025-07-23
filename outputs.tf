# outputs.tf

output "vpc_id" {
  description = "The ID of the newly created VPC"
  value       = aws_vpc.employee_app_vpc.id
}

output "public_subnet_az1_id" {
  description = "ID of the public subnet in AZ1"
  value       = aws_subnet.public_subnet_az1.id
}

output "private_subnet_az1_id" {
  description = "ID of the private subnet in AZ1"
  value       = aws_subnet.private_subnet_az1.id
}

output "private_subnet_az2_id" {
  description = "ID of the private subnet in AZ2"
  value       = aws_subnet.private_subnet_az2.id
}

output "bastion_public_ip" {
  description = "The public IP address of the Bastion Host"
  value       = aws_instance.bastion_host.public_ip
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.employee_app_alb.dns_name
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.employee_app_cluster.name
}

output "ecs_service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.employee_app_service.name
}

output "ecs_fargate_sg_id" {
  description = "The ID of the ECS Fargate Security Group"
  value       = aws_security_group.ecs_fargate_sg.id
}

output "rds_endpoint" {
  description = "Endpoint for the RDS PostgreSQL database"
  value       = aws_db_instance.employees_db.endpoint
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for Docker images"
  value       = aws_ecr_repository.employee_app_repo.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository for Docker images"
  value       = aws_ecr_repository.employee_app_repo.name
}

output "db_init_task_definition_arn" {
  description = "ARN of the Fargate task definition for DB initialization"
  value       = aws_ecs_task_definition.db_init_task.arn
}

output "db_init_task_role_arn" {
  description = "ARN of the IAM role for the DB initialization Fargate task"
  value       = aws_iam_role.db_init_task_role.arn
}
