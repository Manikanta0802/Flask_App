# variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "ap-south-1"
}

variable "my_ip_cidr" {
  description = "Your public IP address in CIDR format for SSH access (e.g., 203.0.113.45/32)"
  type        = string
  default     = "0.0.0.0/0" # WARNING: Change this to your actual IP for production!
}


variable "db_master_username" {
  description = "Master username for the RDS PostgreSQL database"
  type        = string
  default     = "pgadmin"
}


variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
  default     = "office-key" # Ensure this key pair exists in your AWS account
}

variable "db_secret_name" {
  description = "Name of the Secrets Manager secret for DB credentials"
  type        = string
  default     = "employee_app/db_credentials_new_4"
}
