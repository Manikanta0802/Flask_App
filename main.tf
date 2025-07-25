terraform {
  backend "s3" {
    bucket         = "employee-app-terraform-state"
    key            = "employee-app/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-table"
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for latest Amazon Linux 2 AMI (used by bastion module)
data "aws_ami" "amazon_linux_2_ami" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source              = "./modules/vpc"
  aws_region          = var.aws_region
  vpc_cidr_block      = "10.0.0.0/16"
  public_subnet_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr = ["10.0.10.0/24", "10.0.11.0/24"]
}

module "security_groups" {
  source         = "./modules/security_groups"
  vpc_id         = module.vpc.vpc_id
  my_ip_cidr     = var.my_ip_cidr
  alb_sg_id      = module.security_groups.alb_sg_id
}

module "rds" {
  source                = "./modules/rds"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_sg_id             = module.security_groups.rds_sg_id
  db_master_username    = var.db_master_username
  db_master_password    = var.db_master_password
  aws_region            = var.aws_region
  aws_account_id        = data.aws_caller_identity.current.account_id
}

module "ecr" {
  source = "./modules/ecr"
}

module "ecs" {
  source                = "./modules/ecs"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_fargate_sg_id     = module.security_groups.ecs_fargate_sg_id
  alb_tg_arn            = module.alb.target_group_arn
  ecr_repository_url    = module.ecr.repository_url
  rds_instance_address  = module.rds.rds_instance_address
  db_endpoint           = module.rds.rds_endpoint
  db_name               = module.rds.db_name
  db_port               = module.rds.db_port
  db_master_username    = var.db_master_username
  db_master_password    = var.db_master_password
  aws_region            = var.aws_region
  aws_account_id        = data.aws_caller_identity.current.account_id
  depends_on            = [module.alb]
  rds_instance_arn           = module.rds.rds_instance_arn
  db_credentials_secret_arn  = module.rds.db_credentials_secret_arn
}

module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
}

module "bastion" {
  source            = "./modules/bastion"
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  bastion_sg_id     = module.security_groups.bastion_sg_id
  ami_id            = data.aws_ami.amazon_linux_2_ami.id
  key_pair_name     = var.key_pair_name
}

module "cloudwatch" {
  source            = "./modules/cloudwatch"
  alb_id            = module.alb.alb_id
  ecs_cluster_name  = module.ecs.cluster_name
  ecs_service_name  = module.ecs.service_name
  rds_instance_id   = module.rds.rds_instance_id
  log_group_name    = module.ecs.log_group_name
  aws_region        = var.aws_region
}