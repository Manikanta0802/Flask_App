# Employee Application Infrastructure

This repository contains the infrastructure and application code for a Flask-based Employee Management Application, deployed on AWS Fargate with an Amazon RDS PostgreSQL database. The project includes a robust Continuous Integration and Continuous Deployment (CI/CD) pipeline using GitHub Actions to automate building, testing, and deploying the application.

## Overview

The objective of this project is to establish a robust, scalable, secure, and automated deployment pipeline for a Flask-based Application on Amazon Web Services (AWS). This involves defining the entire infrastructure as code using Terraform and orchestrating the build, deployment, and database initialization processes through a GitHub Actions-driven CI/CD pipeline. Key considerations include leveraging managed AWS services, implementing strong security practices, and ensuring comprehensive observability.

## Architecture
The application is deployed on AWS with the following components:

- **Amazon ECS with Fargate**: Runs the Flask application container and a database initialization task.
- **Amazon RDS (PostgreSQL)**: Stores employee data in a managed PostgreSQL database.
- **Application Load Balancer (ALB)**: Routes HTTP traffic to the Flask application at `http://employee-app-alb-852202586.ap-south-1.elb.amazonaws.com`.
- **Amazon ECR**: Hosts the Docker image for the Flask application.
- **AWS VPC**: Provides networking with private subnets and security groups for secure communication.
- **GitHub Actions**: Automates the CI/CD pipeline, including Docker image building, pushing to ECR, infrastructure provisioning with Terraform, and database initialization.

The application exposes:
- A web interface at `/` and `/employee` for viewing employee data.
- A REST API at `/api/employees` for `GET` (retrieve employees) and `POST` (add employees).

## Setup and Deployment
This section guides you through setting up your local environment and deploying the infrastructure and application using the CI/CD pipeline.

### Prerequisites

* AWS Account with necessary permissions.
* AWS CLI configured.
* Terraform (v1.x recommended).
* git installed.
* Docker Desktop (for building and pushing images).
* Your SSH key pair (e.g., app-key.pem) for Bastion Host access.


Then clone this repository.

git clone https://github.com/mani852000/Employee_Web.git
cd Employee_Web

### Setup Instructions
**CRITICAL Steps Before Running the Pipeline:**
**AWS IAM OIDC Setup:**

You MUST set up the OIDC Identity Provider and IAM Role in your AWS account. This is a one-time manual process.

Navigate to IAM (Identity and Access Management)/Identity Providers and click on Add Provider, Select the OpenId Connect and create the token.actions.githubusercontent.com Identity Provider and the github-actions-oidc-role (or whatever you name it) with the correct trust policy and permissions.
<img width="940" height="248" alt="image" src="https://github.com/user-attachments/assets/a2d3e063-46ae-4566-b870-7f6e49265c6c" />

<img width="940" height="362" alt="image" src="https://github.com/user-attachments/assets/84e0a92c-45b3-4c53-a1ea-bc46cc821df2" />


**Create AWS S3 Bucket and DynamoDB Table (Manually for first time):**

**S3 Bucket:** Create an S3 bucket with a globally unique name (e.g., employee-app-terraform-state-yourname-123). This will store your Terraform state file.

**DynamoDB Table:** Create a DynamoDB table with the exact name you used in your main.tf (e.g., employee-app-terraform-locks). The primary key must be LockID (String). This table is for Terraform state locking.

Add the S3, DynamoDB file names to the terraform { backend "s3" { ... } } block at the very top (just after the provider block) with your unique S3 bucket name and unique DynamoDB table name.

**main.tf:**

Ensure the new aws_ecs_task_definition.db_init_task and its related IAM role/policy are present at the end of main.tf as provided in my previous turn. Double-check the command in the db_init_task definition to ensure it precisely matches your desired psql command for creating the table.

**outputs.tf**: Ensure all the new outputs for db_init_task_definition_arn, db_init_task_role_arn, ecr_repository_url, etc., are correctly added.


### Configure GitHub Repository Secrets:

In your GitHub repository, go to Settings > Secrets and variables > Actions > New repository secret.

Add the following secrets, using their exact names as referenced in the deploy.yml:

AWS_ACCOUNT_ID: Your 12-digit AWS Account ID.

GH_ACTIONS_OIDC_ROLE_NAME: The name you gave to the IAM role for GitHub Actions OIDC (e.g., github-actions-oidc-role).

TF_STATE_BUCKET_NAME: The exact name of the S3 bucket you created for Terraform state.

TF_STATE_LOCK_TABLE_NAME: The exact name of the DynamoDB table you created for Terraform state locking.

DB_MASTER_USERNAME: Your RDS master username.

DB_MASTER_PASSWORD: Your RDS master password.

DB_SECRET_NAME: The name of your Secrets Manager secret (employee_app/db_credentials_new_1).
<img width="914" height="393" alt="image" src="https://github.com/user-attachments/assets/bd2489f1-2952-4aea-8cdb-7e35603227bc" />


**Application Files:**

Ensure your Flask application code, Dockerfile, and requirements.txt are in the root of your repository (or adjust the context in the docker/build-push-action).

If you have unit tests, ensure your pytest setup is correct for the pytest step.

Once all these prerequisites are met and your files are committed to the main branch, a push to main will automatically trigger this powerful CI/CD pipeline!

## Destroying the Infrastructure
Once your GitHub repository is set up with the workflow file and secrets, the CI/CD pipeline will automatically trigger on:

**Pushes to the main branch:** Any code changes pushed to main will initiate a new build and deployment.
**Manual Trigger:** You can manually trigger the workflow from the "Actions" tab in your GitHub repository by selecting the "CI/CD Pipeline for Employee App (Fargate)" workflow and clicking "Run workflow."

Monitor the "Actions" tab in your GitHub repository to see the pipeline's progress and logs. 

### Destroying the Infrastructure

To remove all deployed AWS resources You can manually trigger the workflow from the "Actions" tab in your GitHub repository by selecting the "Manually Destroy App Infrastructure" workflow and clicking "Run workflow."

### Important Notes for Cleanup:

**S3 Bucket for ALB Logs:** The aws_s3_bucket.alb_logs_bucket has force_destroy = false by default (a safety measure). If you encounter an error during terraform destroy related to the S3 bucket not being empty or force_destroy being false, you will need to:

Manually empty the S3 bucket (employee-app-alb-logs-<ACCOUNT_ID>) via the AWS Console or AWS CLI.

Then, re-run terraform destroy.

**ECR Repository:** The aws_ecr_repository.employee_app_repo has force_delete = true, so it should be deleted even if it contains images.

## AWS Services Used
VPC (Virtual Private Cloud): Isolated network environment with public and private subnets, Internet Gateway, NAT Gateway, and custom route tables.

EC2 (Elastic Compute Cloud): A Bastion Host (jump box) for secure administrative access.

ECS (Elastic Container Service) Fargate: Serverless compute for running containerized applications without managing underlying EC2 instances.

ECS Cluster: Logical grouping for ECS services.

ECS Service: Maintains the desired count of tasks and integrates with the ALB.

ECS Task Definitions: Blueprints for your application and database initialization containers.

ECR (Elastic Container Registry): A fully managed Docker container registry for storing application images.

RDS (Relational Database Service): Managed PostgreSQL database for the application's data persistence.

ALB (Application Load Balancer): Distributes incoming application traffic across multiple targets (ECS tasks).

Secrets Manager: Securely stores and manages sensitive information like database credentials.

IAM (Identity and Access Management): Manages access to AWS resources, including roles for GitHub Actions, ECS tasks, and the DB initialization task.

CloudWatch: For monitoring and logging:

CloudWatch Logs: Collects logs from ECS tasks.

CloudWatch Metrics: Collects performance metrics from AWS services.

CloudWatch Dashboards: Visualizes key metrics and logs for operational insights.

S3 (Simple Storage Service): Used for:

Terraform remote state storage.

ALB access log storage.

DynamoDB: Used for Terraform state locking to prevent concurrent state modifications.


## Monitoring and Logging
Comprehensive monitoring and logging are set up to provide insights into the application and infrastructure health.
### CloudWatch Logs
•**ECS Application Logs**: All standard output and error streams from your Flask application container are sent to the /ecs/employee-app CloudWatch Log Group.
•	**DB Init Task Logs**: Logs from the database initialization Fargate task are sent to the /ecs/db-init-task CloudWatch Log Group.
•	**Log Retention**: Logs are configured with a 7-day retention period (customizable).
## CloudWatch Metrics & Dashboards
Three dedicated CloudWatch Dashboards are provisioned to give you a holistic view:
**1.	EmployeeApp-Overview**:
o	Key Infrastructure Metrics: ALB Request Count, ECS CPU Utilization, RDS CPU Utilization.
o	Application Error Count: (Assumes your application pushes a custom metric for errors).
o	Recent Application Logs: A log widget showing the latest application logs.
**2.	EmployeeApp-ApplicationHealth**:
o	Application Performance: Custom metrics like Average and P90 Request Duration, and Total Errors (requires your Flask app to publish these custom metrics).
o	ECS Service Health: Running Task Count, CPU Utilization, Memory Utilization for the ECS service.
o	Recent Application Errors in Logs: A log widget filtered to show only error/exception messages from your application logs.
**3.	EmployeeApp-DatabasePerformance**:
o	RDS Core Performance: CPU Utilization, Database Connections, Free Storage Space.
o	RDS I/O Performance: Read/Write IOPS, Read/Write Latency.
o	RDS Network Throughput: Network Receive/Transmit Throughput.
ALB Access Logs
•	The Application Load Balancer is configured to deliver detailed access logs to an S3 bucket (employee-app-alb-logs-<ACCOUNT_ID>). These logs can be analyzed using AWS Athena for insights into traffic patterns, errors, and user behavior.
•	A lifecycle policy is applied to the S3 bucket to automatically expire logs after 90 days (customizable).

# Security Considerations
**VPC Private Subnets:** All core application components (ECS tasks, RDS) are isolated in private subnets.

**Security Groups (Firewall Rules):** Carefully crafted to allow only necessary traffic between components (e.g., ALB to ECS, ECS to RDS) and from trusted sources (your IP for SSH to Bastion).

**IAM Roles & Policies:** Follows the principle of least privilege.

ECS Task Execution Role: Only for ECR pull, CloudWatch Logs.

**ECS Task Role:** For application-specific permissions (e.g., CloudWatch PutMetricData, Secrets Manager GetSecretValue).

**RDS Monitoring Role:** For Enhanced Monitoring.

**AWS Secrets Manager:** Database credentials are not hardcoded. The db_master_password is managed by Secrets Manager (or securely passed during terraform apply). For the application, it should fetch the secret at runtime or have it injected by ECS.

Bastion Host: Provides secure, indirect SSH access to resources in private subnets, acting as a jump box. Ingress is restricted to specific IPs.

# Cost Optimization
**AWS Fargate**: Serverless compute for ECS means you only pay for the vCPU and memory consumed by your running containers.

**RDS Instance Sizing (db.t3.micro)**: Chosen for development/small workloads. For production, size based on performance needs.

**RDS Auto Scaling (Storage)**: RDS can automatically scale storage for you.

**CloudWatch Logs Retention:** Configured to automatically expire logs after a set period (e.g., 7, 30, 90 days) to manage storage costs.

**ALB Access Logs Retention:** S3 lifecycle rules automatically delete older access logs.

**Auto Scaling (ECS Service - Future Enhancement)**: Implement aws_appautoscaling_target and aws_appautoscaling_policy for the ECS service to automatically adjust task count based on CPU/Memory, saving costs during low demand.

# Secret Management
•	**Centralized Storage**: Database credentials (username, password, host, port, dbname) are securely generated by Terraform's random_password resource and stored in AWS Secrets Manager.
•	**Runtime Retrieval**: ECS Task Definitions are configured to retrieve these secrets directly from Secrets Manager at task launch time. The secrets are then injected as environment variables into the container, ensuring they are never hardcoded in Docker images, main.tf, or deploy.yml.
•	**KMS Encryption**: Secrets Manager automatically encrypts secrets at rest using AWS KMS.



# Backup Strategy
Ensuring data durability and recoverability for the RDS PostgreSQL database.

# Automated Backups:

RDS performs daily snapshots and continuously streams transaction logs (WAL).

Configured via backup_retention_period in aws_db_instance (e.g., 7 days). This enables point-in-time recovery.

**Manual Snapshots**: Can be taken anytime via the RDS console or AWS CLI for specific recovery points.

**Multi-AZ Deployment (High Availability)**: While not in the initial main.tf, for production workloads, set multi_az = true in aws_db_instance to automatically provision a standby replica in a different AZ for high availability and disaster recovery.


## Contributing

Contributions are welcome! Please submit pull requests or open issues for bug reports, feature requests, or improvements.
