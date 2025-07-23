# Employee Application Infrastructure

This repository contains the Terraform configuration and application code for the Employee Management Application, deployed on AWS Fargate with an RDS PostgreSQL database.

## Table of Contents
- [Overview](#overview)
- [Architecture Diagram](#architecture-diagram)
- [Deployment](#deployment)
  - [Prerequisites](#prerequisites)
  - [Setup Instructions](#setup-instructions)
  - [Destroying the Infrastructure](#destroying-the-infrastructure)
- [Monitoring & Logging](#monitoring--logging)
- [Security Considerations](#security-considerations)
- [Cost Optimization](#cost-optimization)
- [Secret Management](#secret-management)
- [Backup Strategy](#backup-strategy)
- [Accessing the Database](#accessing-the-database)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This project deploys a Python Flask application for employee management as a containerized service on AWS Fargate. 
It leverages Amazon RDS for PostgreSQL as its database backend and an Application Load Balancer (ALB) for external access. 
The entire infrastructure is defined using Terraform for repeatable and consistent deployments.

## Architecture Diagram

[**Crucial:** Insert a clear, high-level architecture diagram here.]

* **Tools:** Use `draw.io` (now diagrams.net), `Lucidchart`, or even AWS's own `Cloudcraft` or `Architecture Center` for icons.
* **Key Elements to show:**
    * VPC with CIDR (e.g., 10.0.0.0/16)
    * Public Subnets (with Internet Gateway)
    * Private Subnets (with NAT Gateway)
    * Bastion Host (in Public Subnet, pointing to Private)
    * Application Load Balancer (in Public Subnets)
    * ECS Fargate Cluster (ECS Service & Tasks in Private Subnets, behind ALB)
    * RDS PostgreSQL (in Private Subnets, in DB Subnet Group)
    * Security Group Arrows (showing allowed traffic flows)
    * CloudWatch (showing metrics/logs going into it)
    * S3 (for ALB Access Logs, Terraform State)
    * Secrets Manager (showing how secrets are accessed)

## Deployment

### Prerequisites

* AWS Account with necessary permissions.
* AWS CLI configured.
* Terraform (v1.x recommended).
* `git` installed.
* Docker Desktop (for building and pushing images).
* Your SSH key pair (e.g., `app-key.pem`) for Bastion Host access.

### Setup Instructions

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/mani852000/Employee_Web.git
    cd Employee_Web
    ```

2.  **Configure Terraform Backend:**
    If you're using an S3 backend for Terraform state, ensure your `backend.tf` is configured and the S3 bucket and DynamoDB table exist (or create them manually/via a separate script).
    ```terraform
    # backend.tf (example)
    terraform {
      backend "s3" {
        bucket         = "my-terraform-state-bucket"
        key            = "employee-app/terraform.tfstate"
        region         = "ap-south-1"
        encrypt        = true
        dynamodb_table = "my-terraform-state-lock"
      }
    }
    ```

3.  **Prepare SSH Key Pair:**
    Ensure you have an EC2 Key Pair named `app-key` in `ap-south-1` region, and its `.pem` file is at `~/.ssh/app-key.pem` with `chmod 400`. If not, create it:
    ```bash
    aws ec2 create-key-pair --key-name app-key --query 'KeyMaterial' --output text > ~/.ssh/app-key.pem
    chmod 400 ~/.ssh/app-key.pem
    ```

4.  **Create `terraform.tfvars`:**
    Create `terraform.tfvars` in the root:
    ```hcl
    aws_region         = "ap-south-1"
    db_master_username = "pgadmin" # Consistent with previous setup
    db_name            = "employees" # Consistent with previous setup
    # db_master_password will be prompted or supplied via CI/CD
    ```

5.  **Build and Push Docker Images to ECR:**
    * **Login to ECR:**
        ```bash
        aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${your_aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com
        ```
    * **Build & Push `employee-app`:**
        ```bash
        docker build -t employee-app application/
        docker tag employee-app:latest ${your_aws_account_id}.dkr.ecr.${aws_region}[.amazonaws.com/employee-app:latest](https://.amazonaws.com/employee-app:latest)
        docker push ${your_aws_account_id}.dkr.ecr.${aws_region}[.amazonaws.com/employee-app:latest](https://.amazonaws.com/employee-app:latest)
        ```
    * **Build & Push `db-init-container`:**
        ```bash
        docker build -t employee-app-db-init db-init-docker/
        docker tag employee-app-db-init:latest ${your_aws_account_id}.dkr.ecr.${aws_region}[.amazonaws.com/employee-app-db-init:latest](https://.amazonaws.com/employee-app-db-init:latest)
        docker push ${your_aws_account_id}.dkr.ecr.${aws_region}[.amazonaws.com/employee-app-db-init:latest](https://.amazonaws.com/employee-app-db-init:latest)
        ```

6.  **Initialize and Apply Terraform:**
    ```bash
    terraform init
    terraform plan -out tfplan
    terraform apply "tfplan"
    ```
    You will be prompted to enter the `db_master_password`.

7.  **Verify Deployment:**
    * Check AWS Console: EC2, RDS, ECS Cluster, ALB.
    * Get ALB DNS Name: `terraform output alb_dns_name`
    * Access the application: `http://<ALB_DNS_NAME>/employees` (or other defined Flask endpoints).

### Destroying the Infrastructure

To remove all deployed AWS resources (this will incur data loss for the database)

# Security Considerations
VPC Private Subnets: All core application components (ECS tasks, RDS) are isolated in private subnets.

Security Groups (Firewall Rules): Carefully crafted to allow only necessary traffic between components (e.g., ALB to ECS, ECS to RDS) and from trusted sources (your IP for SSH to Bastion).

IAM Roles & Policies: Follows the principle of least privilege.

ECS Task Execution Role: Only for ECR pull, CloudWatch Logs.

ECS Task Role: For application-specific permissions (e.g., CloudWatch PutMetricData, Secrets Manager GetSecretValue).

RDS Monitoring Role: For Enhanced Monitoring.

AWS Secrets Manager: Database credentials are not hardcoded. The db_master_password is managed by Secrets Manager (or securely passed during terraform apply). For the application, it should fetch the secret at runtime or have it injected by ECS.

Bastion Host: Provides secure, indirect SSH access to resources in private subnets, acting as a jump box. Ingress is restricted to specific IPs.

# Cost Optimization
AWS Fargate: Serverless compute for ECS means you only pay for the vCPU and memory consumed by your running containers.

RDS Instance Sizing (db.t3.micro): Chosen for development/small workloads. For production, size based on performance needs.

RDS Auto Scaling (Storage): RDS can automatically scale storage for you.

CloudWatch Logs Retention: Configured to automatically expire logs after a set period (e.g., 7, 30, 90 days) to manage storage costs.

ALB Access Logs Retention: S3 lifecycle rules automatically delete older access logs.

Auto Scaling (ECS Service - Future Enhancement): Implement aws_appautoscaling_target and aws_appautoscaling_policy for the ECS service to automatically adjust task count based on CPU/Memory, saving costs during low demand.

# Secret Management
AWS Secrets Manager is the designated service for handling sensitive data.

# Database Credentials:

The db_master_password used during terraform apply is provided as a sensitive variable.

For db-init-container: The password for the initial database setup is passed directly to the aws_ecs_task via container_overrides.environment or ideally, the container fetches it from Secrets Manager itself if it's a long-running process.

For employee-app-container: The best practice is for your Flask application to explicitly retrieve the db_master_password from Secrets Manager at runtime using the Boto3 SDK, or for the ECS Task Definition to inject the secret value as an environment variable directly from Secrets Manager. This requires permissions (secretsmanager:GetSecretValue, kms:Decrypt) on the ECS Task Role.

# Backup Strategy
Ensuring data durability and recoverability for the RDS PostgreSQL database.

# Automated Backups:

RDS performs daily snapshots and continuously streams transaction logs (WAL).

Configured via backup_retention_period in aws_db_instance (e.g., 7 days). This enables point-in-time recovery.

**Manual Snapshots**: Can be taken anytime via the RDS console or AWS CLI for specific recovery points.

**Multi-AZ Deployment (High Availability)**: While not in the initial main.tf, for production workloads, set multi_az = true in aws_db_instance to automatically provision a standby replica in a different AZ for high availability and disaster recovery.
