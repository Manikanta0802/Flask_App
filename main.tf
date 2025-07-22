# main.tf

# Configure the AWS provider
provider "aws" {
  region = "ap-south-1" # <--- Ensure this matches your desired region
}

# --- Data Sources (VPC and Subnets) ---
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["EmployeeAppVPC"] # Replace with your VPC's Name tag if different
  }
}

data "aws_subnet" "subnet_az1" {
  vpc_id            = data.aws_vpc.selected.id
  availability_zone = "${data.aws_vpc.selected.default_security_group_id}a" # Example for first AZ
  filter {
    name   = "tag:Name"
    values = ["EmployeeAppSubnet-AZ1"] # Replace with your Subnet's Name tag if different
  }
}



# --- Security Group for EC2 Instance ---
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
    from_port   = 8000
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

# --- IAM Role and Instance Profile for EC2 ---
resource "aws_iam_role" "ec2_role" {
  name = "employee_app_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "employee_app_ec2_role"
  }
}

resource "aws_iam_policy" "ec2_s3_secrets_policy" {
  name        = "employee_app_ec2_s3_secrets_policy"
  description = "Policy for EC2 to access S3 and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          # NO S3 BUCKET RESOURCE NEEDED ANYMORE FOR APP FILES - ONLY IF YOU HAVE OTHER S3 BUCKETS
          # If you have other S3 buckets the EC2 instance needs to access, add them here
          # "arn:aws:s3:::your-other-bucket-name",
          # "arn:aws:s3:::your-other-bucket-name/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.db_secret_name}*" # Ensure region is correct
      },
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchGetImage"
        ],
        Resource = "*" # ECR actions often require '*' for resource
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_attach_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_s3_secrets_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "employee_app_ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

# --- EC2 instance ---
resource "aws_instance" "employee_app" {
  ami                         = var.instance_ami
  instance_type               = "t3.micro"
  key_name                    = var.key_pair_name
  subnet_id                   = local.subnet_id_az1
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name

  # User Data Script for Docker setup on EC2 with Git cloning
  user_data = <<-EOF
#!/bin/bash
sudo yum update -y

# --- Install Git, Docker, and necessary tools ---
sudo yum install -y git docker jq postgresql # jq and postgresql client for DB setup
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user # Add ec2-user to the docker group

# Attempt to apply group changes immediately (best practice for scripts)
newgrp docker || true

# --- Retrieve DB Credentials from Secrets Manager ---
# IMPORTANT: Ensure your EC2 IAM role has permissions to read from Secrets Manager
export AWS_DEFAULT_REGION="ap-south-1" # <--- IMPORTANT: REPLACE WITH YOUR ACTUAL AWS REGION if different
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${var.db_secret_name} --query SecretString --output text --region ${var.aws_region})

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

# Define Git Repository URL
GIT_REPO_URL="https://github.com/mani852000/Employee_Web.git" # <--- YOUR GITHUB REPO URL

# Clone the repository
git clone $GIT_REPO_URL /home/ec2-user/employee-app

# Navigate into the cloned repository directory
cd /home/ec2-user/employee-app

echo "Git repository cloned to /home/ec2-user/employee-app."

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

# --- Output the Public IP of the EC2 Instance ---
output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.employee_app.public_ip
}
