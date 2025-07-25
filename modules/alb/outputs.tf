output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.employee_app_alb.dns_name
}

output "target_group_arn" {
  description = "The ARN of the ALB target group"
  value       = aws_lb_target_group.employee_app_tg.arn
}

output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.employee_app_alb.id
}