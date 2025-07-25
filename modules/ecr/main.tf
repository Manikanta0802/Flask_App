resource "aws_ecr_repository" "employee_app_repo" {
  name                 = "employee-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true

  tags = {
    Name = "employee-app-ecr"
  }
}