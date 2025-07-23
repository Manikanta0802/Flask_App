# variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "ap-south-1" # Default region
}

variable "my_ip_cidr" {
  description = "Your public IP address in CIDR format for SSH access to the Bastion Host (e.g., 203.0.113.45/32)."
  type        = string
  default     = "0.0.0.0/0" # WARNING: This allows SSH access from ANYWHERE. For production, change this to your actual public IP address or a more restrictive CIDR block.
}

variable "db_master_username" {
  description = "Master username for the RDS PostgreSQL database."
  type        = string
  default     = "pgadmin" # Default database username
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access to the Bastion Host. Ensure this key pair exists in your AWS account."
  type        = string
  default     = "office-key" # Default SSH key pair name
}


variable "db_secret_name" {
  description = "Name of the Secrets Manager secret for DB credentials"
  type        = string
  default     = "employee_app/db_credentials_new_5"
}
