# main.tf

# Configure Terraform to use an S3 backend for state storage
terraform {
  backend "s3" {
    bucket         = "employee-app-terraform-state"
    key            = "employee-app/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-table"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = { # Declare the random provider
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Data Source for Latest Amazon Linux 2 AMI (for Bastion) ---
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

# --- Current AWS Caller Identity (used for ARN construction) ---
data "aws_caller_identity" "current" {}

# --- Random IDs for unique resource naming ---
resource "random_id" "db_subnet_group_suffix" {
  byte_length = 4
}

resource "random_id" "db_instance_suffix" {
  byte_length = 4
}

# Generate a strong, random password for the RDS database
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*" # Define specific special characters if needed
  numeric          = true
  upper            = true
  lower            = true
  min_special      = 1
  min_numeric      = 1
  min_upper        = 1
  min_lower        = 1
}


# --- VPC ---
resource "aws_vpc" "employee_app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "EmployeeAppVPC"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "employee_app_igw" {
  vpc_id = aws_vpc.employee_app_vpc.id

  tags = {
    Name = "EmployeeAppIGW"
  }
}

# --- Public Subnets ---
resource "aws_subnet" "public_subnet_az1" {
  vpc_id            = aws_vpc.employee_app_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true # Instances in this subnet get public IPs

  tags = {
    Name = "EmployeeAppPublicSubnet-AZ1"
  }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id            = aws_vpc.employee_app_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "EmployeeAppPublicSubnet-AZ2"
  }
}

# --- Private Subnets ---
resource "aws_subnet" "private_subnet_az1" {
  vpc_id            = aws_vpc.employee_app_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = false # Instances in this subnet do NOT get public IPs

  tags = {
    Name = "EmployeeAppPrivateSubnet-AZ1"
  }
}

resource "aws_subnet" "private_subnet_az2" {
  vpc_id            = aws_vpc.employee_app_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "EmployeeAppPrivateSubnet-AZ2"
  }
}

# --- NAT Gateway ---
resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"

  tags = {
    Name = "EmployeeAppNatGW-EIP"
  }
}

resource "aws_nat_gateway" "employee_app_nat_gw" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet_az1.id # Place NAT GW in a public subnet

  tags = {
    Name = "EmployeeAppNatGW"
  }
}

# --- Route Tables ---
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.employee_app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.employee_app_igw.id
  }

  tags = {
    Name = "EmployeeAppPublicRT"
  }
}

resource "aws_route_table_association" "public_subnet_az1_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_az2_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table_az1" {
  vpc_id = aws_vpc.employee_app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.employee_app_nat_gw.id
  }

  tags = {
    Name = "EmployeeAppPrivateRT-AZ1"
  }
}

resource "aws_route_table_association" "private_subnet_az1_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet_az1.id
  route_table_id = aws_route_table.private_route_table_az1.id
}

resource "aws_route_table" "private_route_table_az2" {
  vpc_id = aws_vpc.employee_app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.employee_app_nat_gw.id
  }

  tags = {
    Name = "EmployeeAppPrivateRT-AZ2"
  }
}

resource "aws_route_table_association" "private_subnet_az2_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet_az2.id
  route_table_id = aws_route_table.private_route_table_az2.id
}


# --- Security Groups ---

resource "aws_security_group" "bastion_sg" {
  name        = "employee_app_bastion_sg"
  description = "Allow SSH to bastion host"
  vpc_id      = aws_vpc.employee_app_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH from specific IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound for updates, etc.
  }

  tags = {
    Name = "employee_app_bastion_sg"
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "employee_app_alb_sg"
  description = "Allow HTTP/HTTPS to ALB"
  vpc_id      = aws_vpc.employee_app_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere
    description = "Allow HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS from anywhere (if you add SSL later)
    description = "Allow HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "employee_app_alb_sg"
  }
}

resource "aws_security_group" "ecs_fargate_sg" {
  name        = "employee_app_ecs_fargate_sg"
  description = "Allow traffic from ALB to Fargate tasks, and outbound to RDS and internet"
  vpc_id      = aws_vpc.employee_app_vpc.id

  ingress {
    from_port       = 8000 # Your application's container port
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Allow traffic only from ALB
    description     = "Allow app traffic from ALB"
  }

  # Fargate tasks will need outbound access to ECR, Secrets Manager, etc. via NAT Gateway
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "employee_app_ecs_fargate_sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "employee_app_rds_sg"
  description = "Allow RDS PostgreSQL traffic only from ECS Fargate tasks and DB Init Task"
  vpc_id      = aws_vpc.employee_app_vpc.id

  ingress {
    from_port       = 5432 # PostgreSQL default port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_fargate_sg.id] # Allow from ECS Fargate security group
    description     = "Allow PostgreSQL access from ECS Fargate tasks"
  }

  # Add ingress from Bastion Host for direct DB access
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "Allow PostgreSQL access from Bastion Host"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound for RDS to communicate with other AWS services (e.g. for backups)
  }

  tags = {
    Name = "employee_app_rds_sg"
  }
}

# --- RDS Database (PostgreSQL) ---

resource "aws_db_subnet_group" "employees_db_subnet_group" {
  name        = "employees-db-subnet-group-${random_id.db_subnet_group_suffix.hex}"
  # RDS subnets should be in at least two different AZs and be private
  subnet_ids = [
    aws_subnet.private_subnet_az1.id,
    aws_subnet.private_subnet_az2.id
  ]

  tags = {
    Name = "employees-db-subnet-group"
  }
}


resource "aws_db_instance" "employees_db" {
  identifier            = "employees-db-${random_id.db_instance_suffix.hex}"
  engine                = "postgres"
  engine_version        = "17.4" # Specify a PostgreSQL version
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  storage_type          = "gp2"
  db_name               = "employees"
  username              = var.db_master_username
  password              = random_password.db_password.result # Use the generated password
  skip_final_snapshot   = true
  multi_az              = false # Set to true for production for high availability
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name  = aws_db_subnet_group.employees_db_subnet_group.name
  publicly_accessible   = false # RDS should NOT be publicly accessible

  tags = {
    Name = "employees-db"
  }
}


# --- AWS Secrets Manager for DB Credentials ---

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = var.db_secret_name
  description = "Database credentials for the employee application"

  tags = {
    Name = "EmployeeAppDBCredentials"
  }
}


resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username,
    password = random_password.db_password.result,
    engine   = "postgres",
    host     = aws_db_instance.employees_db.address,
    port     = aws_db_instance.employees_db.port,
    dbname   = aws_db_instance.employees_db.db_name
  })
}


# --- ECR Repository for Docker Images ---
resource "aws_ecr_repository" "employee_app_repo" {
  name                 = "employee-app"
  image_tag_mutability = "MUTABLE" # Or IMMUTABLE for stricter versioning
  image_scanning_configuration {
    scan_on_push = true # Enable vulnerability scanning on push
  }
  force_delete = true

  tags = {
    Name = "employee-app-ecr"
  }
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "employee_app_cluster" {
  name = "employee-app-cluster"

  tags = {
    Name = "employee-app-cluster"
  }
}

# --- IAM Role for ECS Task (for application-specific permissions like Secrets Manager access) ---
resource "aws_iam_role" "ecs_task_role" {
  name = "employee_app_ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "employee_app_ecs_task_role"
  }
}

resource "aws_iam_role_policy" "ecs_task_secrets_policy" {
  name = "ecs-task-secrets-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt" # Required if your secret is encrypted with a custom KMS key
        ],
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*" # Can be scoped down to specific metric ARNs if needed
      }
    ]
  })
}

# --- ECS Task Execution Role (for Fargate to pull images and write logs) ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "employee_app_ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "employee_app_ecs_task_execution_role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- ECS Task Definition (for the main application) ---
resource "aws_ecs_task_definition" "employee_app_task" {
  family                 = "employee-app-task"
  container_definitions  = jsonencode([
    {
      name        = "employee-app-container"
      image       = "${aws_ecr_repository.employee_app_repo.repository_url}:latest" # Image will be pushed by CI/CD
      cpu         = 256 # Fargate CPU units
      memory      = 512 # Fargate Memory units
      essential   = true
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      # Pass DB credentials as environment variables from Secrets Manager
      # The application should then read these environment variables
      secrets = [
        {
          name      = "DB_HOST"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:host::" # Extract 'host' field
        },
        {
          name      = "DB_USER"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:username::" # Extract 'username' field
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::" # Extract 'password' field
        },
        {
          name      = "DB_NAME"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:dbname::" # Extract 'dbname' field
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/employee-app"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  requires_compatibilities = ["FARGATE"] # Now using Fargate
  network_mode             = "awsvpc" # Required for Fargate
  cpu                      = "256" # Total CPU for the task
  memory                   = "512" # Total Memory for the task
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn # Assign the task role for app permissions

  tags = {
    Name = "employee-app-task"
  }
}

# --- Application Load Balancer (ALB) ---
resource "aws_lb" "employee_app_alb" {
  name               = "employee-app-alb"
  internal           = false # Publicly facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  # ALB must be in public subnets
  subnets            = [
    aws_subnet.public_subnet_az1.id,
    aws_subnet.public_subnet_az2.id
  ]
  # Add ALB access logs to S3
  access_logs {
    bucket = aws_s3_bucket.alb_logs_bucket.id
    prefix = "alb-access-logs" # Optional prefix
    enabled = true
  }

  tags = {
    Name = "employee-app-alb"
  }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs_bucket" {
  bucket = "employee-app-alb-logs-${data.aws_caller_identity.current.account_id}" # Unique bucket name
  # Removed the deprecated 'acl' argument
  # Add a bucket policy to allow ALB to write logs to it
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "arn:aws:s3:::employee-app-alb-logs-${data.aws_caller_identity.current.account_id}/alb-access-logs/*" # Adjust prefix
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::employee-app-alb-logs-${data.aws_caller_identity.current.account_id}"
      }
    ]
  })
  tags = {
    Name = "employee-app-alb-logs-bucket"
  }
}

# Separate resource for S3 bucket ACL
resource "aws_s3_bucket_acl" "alb_logs_bucket_acl" {
  bucket = aws_s3_bucket.alb_logs_bucket.id
  acl    = "private"
}

# Separate resource for S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs_bucket_lifecycle" {
  bucket = aws_s3_bucket.alb_logs_bucket.id

  rule {
    id      = "log_retention"
    status  = "Enabled" # Corrected: 'status' is required, 'enabled' is not
    expiration {
      days = 90
    }
  }
}


resource "aws_lb_target_group" "employee_app_tg" {
  name        = "employee-app-tg"
  port        = 8000 # Container port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.employee_app_vpc.id
  target_type = "ip" # Required for Fargate tasks (they register by IP)

  health_check {
    path                = "/" # Or a specific health check endpoint like /health
    protocol            = "HTTP"
    matcher             = "200-299"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "employee-app-tg"
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.employee_app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.employee_app_tg.arn
  }
}

# --- ECS Service ---
resource "aws_ecs_service" "employee_app_service" {
  name            = "employee-app-service"
  cluster         = aws_ecs_cluster.employee_app_cluster.id
  task_definition = aws_ecs_task_definition.employee_app_task.arn
  desired_count   = 1 # Start with 1, can be scaled later
  launch_type     = "FARGATE"

  # Network configuration for Fargate tasks
  network_configuration {
    subnets          = [aws_subnet.private_subnet_az1.id, aws_subnet.private_subnet_az2.id] # Tasks in private subnets
    security_groups  = [aws_security_group.ecs_fargate_sg.id]
    assign_public_ip = false # Fargate tasks in private subnets should not have public IPs
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.employee_app_tg.arn
    container_name   = "employee-app-container"
    container_port   = 8000
  }

  # Ensure the listener is ready before the service tries to register
  depends_on = [
    aws_lb_listener.http_listener
  ]

  tags = {
    Name = "employee-app-service"
  }
}

# --- CloudWatch Log Group for ECS Task Logs ---
resource "aws_cloudwatch_log_group" "ecs_app_logs" {
  name              = "/ecs/employee-app" # Matches logConfiguration in task definition
  retention_in_days = 7 # Adjust as needed

  tags = {
    Name = "employee-app-ecs-logs"
  }
}

# --- Bastion Host EC2 ---
resource "aws_instance" "bastion_host" {
  ami                         = data.aws_ami.amazon_linux_2_ami.id # Standard Amazon Linux 2 AMI
  instance_type               = "t2.micro"
  key_name                    = var.key_pair_name
  subnet_id                   = aws_subnet.public_subnet_az1.id # Place Bastion in a public subnet
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true # Bastion needs a public IP
  # User data for basic setup, though not strictly necessary for a simple bastion
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y telnet net-tools
              EOF

  tags = {
    Name = "EmployeeAppBastionHost"
  }
}

# --- IAM Role for the DB Init Fargate Task ---
resource "aws_iam_role" "db_init_task_role" {
  name = "employee_app_db_init_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "employee_app_db_init_task_role"
  }
}

# --- Policy for the DB Init Fargate Task to connect to RDS and get secrets ---
resource "aws_iam_policy" "db_init_task_policy" {
  name        = "employee_app_db_init_task_policy"
  description = "Policy for DB Init Fargate task to access RDS and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds-db:connect",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt" # Required if your secret is encrypted with a custom KMS key
        ],
        Resource = [
          aws_db_instance.employees_db.arn,
          aws_secretsmanager_secret.db_credentials.arn,
          # If a custom KMS key is used for Secrets Manager, its ARN should be here as well
        ]
      },
      { # Permissions for CloudWatch Logs for the DB Init Task
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/db-init-task:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_init_task_role_policy_attachment" {
  role       = aws_iam_role.db_init_task_role.name
  policy_arn = aws_iam_policy.db_init_task_policy.arn
}

# --- Task Definition for the DB Init Fargate Task ---
# This task will run a simple image with psql client to initialize the DB.
resource "aws_ecs_task_definition" "db_init_task" {
  family                 = "employee-app-db-init-task"
  requires_compatibilities = ["FARGATE"]
  network_mode           = "awsvpc"
  cpu                    = "256"
  memory                 = "512"
  # Reusing ecs_task_execution_role for pulling image/logging if needed.
  execution_role_arn     = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn          = aws_iam_role.db_init_task_role.arn # Assign the task role for DB access and secrets

  container_definitions  = jsonencode([
    {
      name    = "db-init-container"
      image   = "public.ecr.aws/docker/library/postgres:16-alpine"
      command = ["/bin/sh", "-c", "/usr/local/bin/psql -h \"$DB_HOST\" -U \"$DB_USER\" -d \"$DB_NAME\" -p \"$DB_PORT\" -w -c \"CREATE TABLE IF NOT EXISTS employees (id SERIAL PRIMARY KEY, name VARCHAR(100), employee_id VARCHAR(100) UNIQUE, email VARCHAR(100) UNIQUE);\""]
      secrets = [ # Fetch DB credentials from Secrets Manager
        {
          name      = "DB_HOST"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:host::"
        },
        {
          name      = "DB_USER"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:username::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:dbname::"
        },
        {
          name      = "DB_PORT"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:port::"
        },
        {
          name      = "PGPASSWORD" # psql client uses PGPASSWORD env var
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/db-init-task"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "db-init"
        }
      }
    }
  ])

  tags = {
    Name = "employee-app-db-init-task"
  }
}

# --- CloudWatch Log Group for DB Init Task Logs ---
resource "aws_cloudwatch_log_group" "db_init_task_logs" {
  name              = "/ecs/db-init-task"
  retention_in_days = 7

  tags = {
    Name = "employee-app-db-init-logs"
  }
}

# --- CloudWatch Dashboard: EmployeeApp-Overview ---
resource "aws_cloudwatch_dashboard" "employee_app_dashboard" {
  dashboard_name = "EmployeeApp-Overview"
  dashboard_body = jsonencode({
    "widgets" = [
      {
        "type"   = "metric"
        "x"      = 0
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            # Example: ALB Request Count
            [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.employee_app_alb.id ],
            # Example: ECS Service CPU Utilization
            [ "AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.employee_app_cluster.name, "ServiceName", aws_ecs_service.employee_app_service.name ],
            # Example: RDS CPU Utilization
            [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.employees_db.id ]
          ],
          "view"       = "timeSeries"
          "stacked"    = false
          "period"     = 300
          "stat"       = "Average"
          "region"     = var.aws_region
          "title"      = "Key Infrastructure Metrics"
        }
      },
      {
        "type"   = "metric"
        "x"      = 12
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            # Example: Custom Flask App Errors (requires application to push this metric)
            [ "EmployeeApp/Flask", "ErrorCount", "Application", "EmployeeApp" ]
          ],
          "view"       = "timeSeries"
          "stacked"    = false
          "period"     = 300
          "stat"       = "Sum"
          "region"     = var.aws_region
          "title"      = "Application Error Count"
        }
      },
      {
        "type"   = "log"
        "x"      = 0
        "y"      = 6
        "width"  = 24
        "height" = 6
        "properties" = {
          "query"       = "SOURCE '${aws_cloudwatch_log_group.ecs_app_logs.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          "region"      = var.aws_region
          "title"       = "Recent Application Logs"
          "view"        = "table"
        }
      }
    ]
  })
}

# --- CloudWatch Dashboard: EmployeeApp-ApplicationHealth ---
resource "aws_cloudwatch_dashboard" "employee_app_application_health_dashboard" {
  dashboard_name = "EmployeeApp-ApplicationHealth"
  dashboard_body = jsonencode({
    "widgets" = [
      {
        "type"   = "metric"
        "x"      = 0
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            # Custom Application Metrics (assuming your Flask app pushes these)
            [ "EmployeeApp/Flask", "RequestDuration", "Endpoint", "all", { "stat": "Average", "label": "Avg Request Duration" } ],
            [ "EmployeeApp/Flask", "RequestDuration", "Endpoint", "all", { "stat": "p90", "label": "P90 Request Duration" } ],
            [ "EmployeeApp/Flask", "ErrorCount", "Application", "EmployeeApp", { "stat": "Sum", "label": "Total Errors" } ]
          ],
          "view"       = "timeSeries"
          "stacked"    = false
          "period"     = 60 # More frequent for app health
          "stat"       = "Average"
          "region"     = var.aws_region
          "title"      = "Application Performance"
        }
      },
      {
        "type"   = "metric"
        "x"      = 12
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            # ECS Service Health
            [ "AWS/ECS", "RunningTaskCount", "ClusterName", aws_ecs_cluster.employee_app_cluster.name, "ServiceName", aws_ecs_service.employee_app_service.name ],
            [ "AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.employee_app_cluster.name, "ServiceName", aws_ecs_service.employee_app_service.name ],
            [ "AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.employee_app_cluster.name, "ServiceName", aws_ecs_service.employee_app_service.name ]
          ],
          "view"       = "timeSeries"
          "stacked"    = false
          "period"     = 300
          "stat"       = "Average"
          "region"     = var.aws_region
          "title"      = "ECS Service Health"
        }
      },
      {
        "type"   = "log"
        "x"      = 0
        "y"      = 6
        "width"  = 24
        "height" = 6
        "properties" = {
          "query"       = "SOURCE '${aws_cloudwatch_log_group.ecs_app_logs.name}' | filter @message like /error|exception/ | fields @timestamp, @message | sort @timestamp desc | limit 20"
          "region"      = var.aws_region
          "title"       = "Recent Application Errors in Logs"
          "view"        = "table"
        }
      }
    ]
  })
}

# --- CloudWatch Dashboard: EmployeeApp-DatabasePerformance ---
resource "aws_cloudwatch_dashboard" "employee_app_database_performance_dashboard" {
  dashboard_name = "EmployeeApp-DatabasePerformance"
  dashboard_body = jsonencode({
    "widgets" = [
      {
        "type"   = "metric"
        "x"      = 0
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.employees_db.id, { "label": "CPU Utilization (Average)" } ],
            [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.employees_db.id, { "label": "Database Connections (Average)" } ],
            [ "AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.employees_db.id, { "label": "Free Storage Space (Min)", "stat": "Minimum", "yAxis": { "left": { "showUnits": true } } } ]
          ],
          "view"       = "timeSeries"
          "stacked"    = false
          "period"     = 300
          "stat"       = "Average"
          "region"     = var.aws_region
          "title"      = "RDS Core Performance"
        }
      },
      {
        "type"   = "metric"
        "x"      = 12
        "y"      = 0
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            [ "AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", aws_db_instance.employees_db.id, { "label": "Read IOPS (Average)" } ],
            [ "AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", aws_db_instance.employees_db.id, { "label": "Write IOPS (Average)" } ],
            [ "AWS/RDS", "ReadLatency", "DBInstanceIdentifier", aws_db_instance.employees_db.id, { "label": "Read Latency (Average)" } ],
            [ "AWS/RDS", "WriteLatency", "DBInstanceIdentifier", aws_db_instance.employees_db.id, { "label": "Write Latency (Average)" } ]
          ],
          "view"       = "timeSeries"
          "stacked"    = false
          "period"     = 300
          "stat"       = "Average"
          "region"     = var.aws_region
          "title"      = "RDS I/O Performance"
        }
      },
      {
        "type"   = "metric"
        "x"      = 0
        "y"      = 6
        "width"  = 12
        "height" = 6
        "properties" = {
          "metrics" = [
            [ "AWS/RDS", "NetworkReceiveThroughput", "DBInstanceIdentifier", aws_db_instance.employees_db.id, { "label": "Network Receive (Average)" } ],
            [ "AWS/RDS", "NetworkTransmitThroughput", "DBInstanceIdentifier", aws_db_instance.employees_db.id, { "label": "Network Transmit (Average)" } ]
          ],
          "view"       = "timeSeries"
          "stacked"    = false
          "period"     = 300
          "stat"       = "Average"
          "region"     = var.aws_region
          "title"      = "RDS Network Throughput"
        }
      }
    ]
  })
}
