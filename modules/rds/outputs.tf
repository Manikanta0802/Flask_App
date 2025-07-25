output "rds_endpoint" {
  description = "Endpoint for the RDS PostgreSQL database"
  value       = aws_db_instance.employees_db.endpoint
}

output "rds_instance_id" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.employees_db.identifier
}

output "rds_instance_address" {
  description = "Hostname of the RDS instance (without port)"
  value       = split(":", aws_db_instance.employees_db.endpoint)[0]
}

output "db_name" {
  description = "Name of the RDS database"
  value       = aws_db_instance.employees_db.db_name
}

output "db_port" {
  description = "Port of the RDS database"
  value       = aws_db_instance.employees_db.port
}

output "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret for DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "rds_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.employees_db.arn
}