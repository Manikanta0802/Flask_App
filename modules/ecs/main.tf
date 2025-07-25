resource "aws_ecs_cluster" "employee_app_cluster" {
  name = "employee-app-cluster"

  tags = {
    Name = "employee-app-cluster"
  }
}

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
      }
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

resource "aws_ecs_task_definition" "employee_app_task" {
  family                = "employee-app-task"
  container_definitions = jsonencode([
    {
      name      = "employee-app-container"
      image     = "${var.ecr_repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DB_HOST"
          value = var.db_endpoint
        },
        {
          name  = "DB_USER"
          value = var.db_master_username
        },
        {
          name  = "DB_PASSWORD"
          value = var.db_master_password
        },
        {
          name  = "DB_NAME"
          value = var.db_name
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
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  tags = {
    Name = "employee-app-task"
  }
}

resource "aws_ecs_service" "employee_app_service" {
  name            = "employee-app-service"
  cluster         = aws_ecs_cluster.employee_app_cluster.id
  task_definition = aws_ecs_task_definition.employee_app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_fargate_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_tg_arn
    container_name   = "employee-app-container"
    container_port   = 8000
  }

  depends_on = [var.alb_tg_arn]

  tags = {
    Name = "employee-app-service"
  }
}

resource "aws_cloudwatch_log_group" "ecs_app_logs" {
  name              = "/ecs/employee-app"
  retention_in_days = 7

  tags = {
    Name = "employee-app-ecs-logs"
  }
}

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
      }
    ]
  })

  tags = {
    Name = "employee_app_db_init_task_role"
  }
}

resource "aws_iam_policy" "db_init_task_policy" {
  name        = "employee_app_db_init_task_policy"
  description = "Policy for DB Init Fargate task to access RDS and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect",
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.rds_instance_arn,
          var.db_credentials_secret_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/db-init-task:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_init_task_role_policy_attachment" {
  role       = aws_iam_role.db_init_task_role.name
  policy_arn = aws_iam_policy.db_init_task_policy.arn
}

resource "aws_ecs_task_definition" "db_init_task" {
  family                   = "employee-app-db-init-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.db_init_task_role.arn

  container_definitions = jsonencode([
    {
      name    = "db-init-container"
      image   = "public.ecr.aws/docker/library/postgres:16-alpine"
      command = ["/bin/sh", "-c", "/usr/local/bin/psql -h \"$DB_HOST\" -U \"$DB_USER\" -d \"$DB_NAME\" -p \"$DB_PORT\" -w -c \"CREATE TABLE IF NOT EXISTS employees (id SERIAL PRIMARY KEY, name VARCHAR(100), employee_id VARCHAR(100) UNIQUE, email VARCHAR(100) UNIQUE);\""]
      environment = [
        {
          name  = "DB_HOST"
          value = var.db_endpoint
        },
        {
          name  = "DB_USER"
          value = var.db_master_username
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_PORT"
          value = tostring(var.db_port)
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

resource "aws_cloudwatch_log_group" "db_init_task_logs" {
  name              = "/ecs/db-init-task"
  retention_in_days = 7

  tags = {
    Name = "employee-app-db-init-logs"
  }
}