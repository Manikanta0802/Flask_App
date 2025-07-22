provider "aws" {
  region = "ap-south-1"
}



# --- Data Source for VPC ID ---
data "aws_subnet" "selected_subnet" {
  id = var.subnet_id_az1
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.selected_subnet.vpc_id
}

# --- Security Groups ---

resource "aws_security_group" "ec2_sg" {
  name        = "employee_app_ec2_sg"
  description = "Allow HTTP and SSH traffic to EC2 instance"
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
  name = "employees-db-subnet-group-${random_id.db_subnet_group_suffix.hex}"
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
  identifier             = "employees-db-${random_id.db_instance_suffix.hex}"
  engine                 = "postgres"
  engine_version         = "17.4" # Specify a PostgreSQL version
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "employees"
  username               = var.db_master_username # Master username for initial access
  password               = var.db_master_password # Master password for initial access
  skip_final_snapshot    = true
  multi_az               = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.employees_db_subnet_group.name
  publicly_accessible    = true

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

# --- S3 bucket to store app files ---
resource "aws_s3_bucket" "app_files" {
  bucket = "employee-app-files-${random_id.bucket_id.hex}" # Unique bucket name

  tags = {
    Name = "EmployeeAppFiles"
  }
}

resource "random_id" "bucket_id" {
  byte_length = 4
}

# Upload files to S3 bucket
resource "aws_s3_object" "employee_app" {
  bucket = aws_s3_bucket.app_files.id
  key    = "employee_app.py"
  source = "${path.module}/employee_app.py"
  acl    = "private"
  etag   = filemd5("${path.module}/employee_app.py") # Add ETag for content changes
}

resource "aws_s3_object" "employee_index" {
  bucket = aws_s3_bucket.app_files.id
  key    = "templates/employee_index.html"
  source = "${path.module}/employee_index.html"
  acl    = "private"
  etag   = filemd5("${path.module}/employee_index.html")
}

resource "aws_s3_object" "employee_details" {
  bucket = aws_s3_bucket.app_files.id
  key    = "templates/employee_details.html"
  source = "${path.module}/employee_details.html"
  acl    = "private"
  etag   = filemd5("${path.module}/employee_details.html")
}

# --- IAM Role for EC2 to access S3 and Secrets Manager ---
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
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.app_files.arn,
          "${aws_s3_bucket.app_files.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = "secretsmanager:GetSecretValue",
        Resource = aws_secretsmanager_secret.db_credentials.arn # Allow access to specific secret
      }
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

  # User Data Script for setup
  user_data = <<-EOF
#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras install python3.8 -y

# Enable a newer PostgreSQL client version using amazon-linux-extras
sudo amazon-linux-extras enable postgresql13 # Or postgresql14, depending on availability. postgresql13 is a good starting point.
sudo yum clean metadata # Clean yum cache after enabling new extras

sudo yum install -y python3-pip python3-devel gcc postgresql-devel jq postgresql # Ensure postgresql and postgresql-devel are installed here after enabling extras

# Create app directory and navigate into it
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies including Gunicorn
pip install Flask Gunicorn psycopg2-binary boto3

# Create templates directory if it doesn't exist
mkdir -p templates


# --- FIX: Dynamically get S3 bucket name from Terraform ---
# The bucket name 'aws_s3_bucket.app_files.bucket' is injected by Terraform.
# This line is correct as is: Terraform substitutes the bucket name directly.
S3_BUCKET_NAME="${aws_s3_bucket.app_files.bucket}"

# Download application files from S3 using the dynamic bucket name
# CRITICAL FIX: Use $$ for the shell variable S3_BUCKET_NAME so Terraform doesn't try to expand it.
aws s3 cp s3://$${S3_BUCKET_NAME}/employee_app.py ./app.py
aws s3 cp s3://$${S3_BUCKET_NAME}/templates/employee_index.html templates/employee_index.html
aws s3 cp s3://$${S3_BUCKET_NAME}/templates/employee_details.html templates/employee_details.html


# --- Retrieve DB Credentials from Secrets Manager ---
export AWS_DEFAULT_REGION="ap-south-1" # <--- IMPORTANT: REPLACE WITH YOUR ACTUAL AWS REGION
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id employee_app/db_credentials_new_1 --query SecretString --output text --region ap-south-1)

DB_HOST=$(echo $SECRET_JSON | jq -r '.host')
DB_USER=$(echo $SECRET_JSON | jq -r '.username')
DB_PASSWORD=$(echo $SECRET_JSON | jq -r '.password')
DB_NAME=$(echo $SECRET_JSON | jq -r '.dbname')

echo "DB_HOST: $DB_HOST"
echo "DB_USER: $DB_USER"
echo "DB_NAME: $DB_NAME"

# --- Force SSL for psql connections via environment variable ---
export PGSSLMODE=require

# --- Initial Database Setup using retrieved credentials ---

# Wait for PostgreSQL to be available
ATTEMPTS=0
MAX_ATTEMPTS=30
echo "Waiting for PostgreSQL to be available..."
until PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c '\q' || [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; do
    echo "Waiting for PostgreSQL to be available... (Attempt $((ATTEMPTS+1)) of $MAX_ATTEMPTS)"
    sleep 2
    ATTEMPTS=$((ATTEMPTS+1))
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    echo "ERROR: PostgreSQL did not become available after $MAX_ATTEMPTS attempts."
    exit 1
fi

echo "PostgreSQL is available. Proceeding with database and table creation."

# Create database if it doesn't exist
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null


# Create 'employees' table 
echo "Creating 'employees' table"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    employee_id VARCHAR(100) UNIQUE,  -- <--- ADD THIS LINE
    email VARCHAR(100) UNIQUE
);
" # <--- THIS DOUBLE QUOTE IS THE CRITICAL FIX FOR THE SYNTAX ERROR!


# Create a systemd service file for the Flask app
sudo tee /etc/systemd/system/employee_app.service > /dev/null <<EOL
[Unit]
Description=Gunicorn instance of Flask Employee App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/app
Environment="PATH=/home/ec2-user/app/venv/bin"
Environment="FLASK_APP=app.py"
Environment="DB_HOST=$${DB_HOST}"
Environment="DB_USER=$${DB_USER}"
Environment="DB_PASSWORD=$${DB_PASSWORD}"
Environment="DB_NAME=$${DB_NAME}"
ExecStart=/home/ec2-user/app/venv/bin/gunicorn --workers 4 --bind 0.0.0.0:8000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable, and start the service
sudo systemctl daemon-reload
sudo systemctl enable employee_app.service
sudo systemctl start employee_app.service

echo "Flask Employee App setup complete and service started."

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
  value       = "http://${aws_instance.employee_app.public_ip}"
  description = "URL to access the Employee App"
}

output "rds_endpoint" {
  value       = aws_db_instance.employees_db.endpoint
  description = "Endpoint for the RDS PostgreSQL database"
}
