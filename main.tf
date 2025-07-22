# main.tf

provider "aws" {
  region = "ap-south-1" # Your AWS Region
}

# --- Data Source for VPC ID and Subnet ---
data "aws_subnet" "selected_subnet" {
  id = var.subnet_id_az1
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.selected_subnet.vpc_id
}

# --- Security Groups ---

resource "aws_security_group" "ec2_sg" {
  name        = "employee_app_ec2_sg"
  description = "Allow HTTP, SSH, and App traffic to EC2 instance"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere
    description = "Allow HTTP access"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr] # IMPORTANT: Restrict SSH to your IP!
    description = "Allow SSH access from specified IP"
  }

  ingress {
    from_port   = 8000 # Port for your Flask app
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow app traffic on port 8000 from anywhere
    description = "Allow app traffic on port 8000"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "employee_app_ec2_sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "employee_app_rds_sg"
  description = "Allow RDS PostgreSQL traffic only from EC2 SG"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port       = 5432 # PostgreSQL default port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id] # Allow from EC2 security group only
    description     = "Allow PostgreSQL access from EC2 instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # RDS might need to talk to S3 for snapshots etc.
  }

  tags = {
    Name = "employee_app_rds_sg"
  }
}

# --- RDS Database (PostgreSQL) ---

resource "aws_db_subnet_group" "employees_db_subnet_group" {
  name       = "employees-db-subnet-group-${random_id.db_subnet_group_suffix.hex}"
  subnet_ids = [
    var.subnet_id_az1,
    var.subnet_id_az2
  ]

  tags = {
    Name = "employees-db-subnet-group"
  }
}

resource "random_id" "db_subnet_group_suffix" {
  byte_length = 4
}


resource "aws_db_instance" "employees_db" {
  identifier           = "employees-db-${random_id.db_instance_suffix.hex}"
  engine               = "postgres"
  engine_version       = "17.4" # Specify a PostgreSQL version
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  db_name              = "employees"
  username             = var.db_master_username # Master username for initial access
  password             = var.db_master_password # Master password for initial access
  skip_final_snapshot  = true
  multi_az             = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.employees_db_subnet_group.name
  publicly_accessible  = true

  tags = {
    Name = "employees-db"
  }
}

resource "random_id" "db_instance_suffix" {
  byte_length = 4
}

# --- AWS Secrets Manager for DB Credentials ---

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "employee_app/db_credentials_new_1"
  description = "Database credentials for the employee application"

  tags = {
    Name = "EmployeeAppDBCredentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username,
    password = var.db_master_password,
    engine   = "postgres",
    host     = aws_db_instance.employees_db.address, # Use .address for endpoint without port
    port     = aws_db_instance.employees_db.port,    # RDS returns integer port
    dbname   = aws_db_instance.employees_db.db_name
  })
}

# --- IAM Role for EC2 to access Secrets Manager ---
resource "aws_iam_role" "ec2_role" {
  name = "ec2_app_access_role_${random_id.role_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "random_id" "role_suffix" {
  byte_length = 4
}

resource "aws_iam_role_policy" "ec2_role_policy" {
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "secretsmanager:GetSecretValue",
        Resource = aws_secretsmanager_secret.db_credentials.arn # Allow access to specific secret
      }
      # No S3 permissions needed here as we are using Git to fetch files
      # You might add ECR permissions later if you push/pull Docker images from ECR
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_app_instance_profile_${random_id.instance_profile_suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

resource "random_id" "instance_profile_suffix" {
  byte_length = 4
}


# --- EC2 instance ---
resource "aws_instance" "employee_app" {
  ami                         = var.instance_ami
  instance_type               = "t2.micro"
  key_name                    = var.key_pair_name
  subnet_id                   = var.subnet_id_az1
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name

  # User Data Script for Docker setup with Git cloning
  user_data = <<-EOF
#!/bin/bash
sudo yum update -y

# --- Install Git, Docker, and necessary tools ---
sudo yum install -y git docker jq postgresql # git, docker, jq, and postgresql client for DB setup
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user # Add ec2-user to the docker group

# Attempt to apply group changes immediately (best practice for scripts)
newgrp docker || true

# --- Retrieve DB Credentials from Secrets Manager ---
# IMPORTANT: Ensure your EC2 IAM role has permissions to read from Secrets Manager
export AWS_DEFAULT_REGION="ap-south-1" # <--- IMPORTANT: This should match your provider region
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db_credentials.name} --query SecretString --output text --region ap-south-1)

DB_HOST=$(echo $SECRET_JSON | jq -r '.host')
DB_USER=$(echo $SECRET_JSON | jq -r '.username')
DB_PASSWORD=$(echo $SECRET_JSON | jq -r '.password')
DB_NAME=$(echo $SECRET_JSON | jq -r '.dbname')

echo "DB_HOST: $DB_HOST"
echo "DB_USER: $DB_USER"
echo "DB_NAME: $DB_NAME"

# --- Initial Database Setup (still on EC2 host, outside Docker) ---
# This ensures the database and table exist before the app tries to connect
export PGSSLMODE=require

# 1. Wait for PostgreSQL to be available (connect as master user to 'postgres' database)
ATTEMPTS=0
MAX_ATTEMPTS=30
echo "Waiting for PostgreSQL to be available as master user..."
until PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d postgres -c '\q' || [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; do
    echo "Waiting for PostgreSQL to be available... (Attempt $((ATTEMPTS+1)) of $MAX_ATTEMPTS)"
    sleep 2
    ATTEMPTS=$((ATTEMPTS+1))
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    echo "ERROR: PostgreSQL did not become available as master user after $MAX_ATTEMPTS attempts."
    exit 1
fi

echo "PostgreSQL is available. Proceeding with initial setup using master user."

# 2. Create 'employees' database if it doesn't exist (as master user)
echo "Creating database '$DB_NAME' if it does not exist..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d postgres -c "
    SELECT 'CREATE DATABASE $DB_NAME' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')
" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d postgres # Execute the output as a new psql command

# 3. Create 'employees' table (as master user)
echo "Creating 'employees' table as master user..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    employee_id VARCHAR(100) UNIQUE,
    email VARCHAR(100) UNIQUE
);
"

# --- Git Clone, Docker Image Build, and Run on EC2 ---

# Define Git Repository URL (from your GitHub repo)
GIT_REPO_URL="https://github.com/mani852000/Employee_Web.git" # <--- YOUR GITHUB REPO URL

# Clone the repository into a dedicated directory
# The directory name will be the repo name by default (Employee_Web)
git clone $GIT_REPO_URL /home/ec2-user/employee-app-repo

# Navigate into the cloned repository directory for Docker build
cd /home/ec2-user/employee-app-repo

echo "Git repository cloned to /home/ec2-user/employee-app-repo."

# Build the Docker image
# Name the image 'employee-app'
sudo docker build -t employee-app . # Use sudo because the build process needs root permissions

echo "Docker image 'employee-app' built on EC2."

# Run the Docker container
sudo docker run -d \
    -p 8000:8000 \
    --name employee-app-container \
    --restart=always \
    -e DB_HOST="$${DB_HOST}" \
    -e DB_USER="$${DB_USER}" \
    -e DB_PASSWORD="$${DB_PASSWORD}" \
    -e DB_NAME="$${DB_NAME}" \
    employee-app

echo "Docker container for employee-app started on EC2."

EOF

  tags = {
    Name = "EmployeeAppInstance"
  }
}

# Outputs
output "employee_app_public_ip" {
  value       = aws_instance.employee_app.public_ip
  description = "Public IP address of the Employee App EC2 instance"
}

output "employee_app_url" {
  value       = "http://${aws_instance.employee_app.public_ip}:8000" # Include port 8000 for clarity
  description = "URL to access the Employee App"
}

output "rds_endpoint" {
  value       = aws_db_instance.employees_db.endpoint
  description = "Endpoint for the RDS PostgreSQL database"
}
