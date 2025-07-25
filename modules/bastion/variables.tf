variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet for the bastion host"
  type        = string
}

variable "bastion_sg_id" {
  description = "The ID of the bastion security group"
  type        = string
}

variable "ami_id" {
  description = "The ID of the AMI for the bastion host"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
}