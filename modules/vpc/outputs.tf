output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.employee_app_vpc.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [aws_subnet.private_subnet_az1.id, aws_subnet.private_subnet_az2.id]
}