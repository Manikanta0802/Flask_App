resource "aws_instance" "bastion_host" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  key_name                    = var.key_pair_name
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y telnet net-tools
              EOF

  tags = {
    Name = "EmployeeAppBastionHost"
  }
}