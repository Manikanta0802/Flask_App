output "bastion_sg_id" {
  description = "The ID of the bastion security group"
  value       = aws_security_group.bastion_sg.id
}

output "alb_sg_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "ecs_fargate_sg_id" {
  description = "The ID of the ECS Fargate security group"
  value       = aws_security_group.ecs_fargate_sg.id
}

output "rds_sg_id" {
  description = "The ID of the RDS security group"
  value       = aws_security_group.rds_sg.id
}