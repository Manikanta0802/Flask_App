output "repository_url" {
  description = "URL of the ECR repository for Docker images"
  value       = aws_ecr_repository.employee_app_repo.repository_url
}

output "repository_name" {
  description = "Name of the ECR repository for Docker images"
  value       = aws_ecr_repository.employee_app_repo.name
}