resource "aws_db_subnet_group" "employees_db_subnet_group" {
  name       = "employees-db-subnet-group-${random_id.db_subnet_group_suffix.hex}"
  subnet_ids = var.private_subnet_ids

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
  engine_version         = "17.4"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "employees"
  username               = var.db_master_username
  password               = var.db_master_password
  skip_final_snapshot    = true
  multi_az               = false
  vpc_security_group_ids = [var.rds_sg_id]
  db_subnet_group_name   = aws_db_subnet_group.employees_db_subnet_group.name
  publicly_accessible    = false

  tags = {
    Name = "employees-db"
  }
}

resource "random_id" "db_instance_suffix" {
  byte_length = 4
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "employee_app/${aws_db_instance.employees_db.identifier}_secrets"
  description = "Database credentials for the employee application"

  tags = {
    Name = "EmployeeAppDBCredentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = var.db_master_password
    engine   = "postgres"
    host     = aws_db_instance.employees_db.address
    port     = aws_db_instance.employees_db.port
    dbname   = aws_db_instance.employees_db.db_name
  })
}