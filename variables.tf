variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "ap-south-1"
}

variable "my_ip_cidr" {
  description = "Your public IP address in CIDR format for SSH access (e.g., 203.0.113.45/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_master_username" {
  description = "Master username for the RDS PostgreSQL database"
  type        = string
  default     = "pgadmin"
}

variable "db_master_password" {
  description = "Master password for the RDS PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
  default     = "office-key"
}