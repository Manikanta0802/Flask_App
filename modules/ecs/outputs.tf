output "cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.employee_app_cluster.name
}

output "service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.employee_app_service.name
}

output "db_init_task_definition_arn" {
  description = "ARN of the Fargate task definition for DB initialization"
  value       = aws_ecs_task_definition.db_init_task.arn
}

output "db_init_task_role_arn" {
  description = "ARN of the IAM role for the DB initialization Fargate task"
  value       = aws_iam_role.db_init_task_role.arn
}

output "log_group_name" {
  description = "Name of the ECS application log group"
  value       = aws_cloudwatch_log_group.ecs_app_logs.name
}