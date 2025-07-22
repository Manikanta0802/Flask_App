# --- Variables (Best Practice: Use variables for configurable values) ---
variable "subnet_id_az1" {
  description = "ID of the first subnet in AZ1 for RDS and EC2"
  type        = string
  default     = "subnet-0ac6935ca0c433c05" # REPLACE with your actual subnet ID in AZ1
}

variable "subnet_id_az2" {
  description = "ID of the second subnet in AZ2 for RDS"
  type        = string
  default     = "subnet-0902bdf1a4a734e60" # REPLACE with your actual subnet ID in AZ2
}

variable "my_ip_cidr" {
  description = "Your public IP address in CIDR format for SSH access (e.g., 203.0.113.45/32)"
  type        = string
  default     = "0.0.0.0/0" # WARNING: Change this to your actual IP for production!
}

variable "db_master_username" {
  description = "Master username for the RDS PostgreSQL database (used for initial setup)"
  type        = string
  default     = "pgadmin" # PostgreSQL default master username
}

variable "db_master_password" {
  description = "Master password for the RDS PostgreSQL database (used for initial setup)"
  type        = string
  sensitive   = true
  default     = "PgAchala1234" # Change this to a strong password for initial setup!
}

variable "instance_ami" {
  description = "AMI ID for the EC2 instance (Amazon Linux 2 or 2023)"
  type        = string
  default     = "ami-0327f51db613d7bd2" # Amazon Linux 2 AMI
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
  default     = "office-key" # Ensure this key pair exists in your AWS account
}