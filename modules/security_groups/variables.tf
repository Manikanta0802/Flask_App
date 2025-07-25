variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your public IP address in CIDR format for SSH access"
  type        = string
}

variable "alb_sg_id" {
  description = "The ID of the ALB security group"
  type        = string
}