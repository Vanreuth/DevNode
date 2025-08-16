terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "ap-southeast-1" # change to your preferred region
}

# Variable for SSH public key
variable "ec2_ssh_pub_key" {
  description = "SSH public key for EC2 access"
  type        = string
}

# Security group
resource "aws_security_group" "node_sg" {
  name        = "nodejs-sg"
  description = "Allow SSH, HTTP, HTTPS"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Key pair (use variable for public key)
resource "aws_key_pair" "node_key" {
  key_name   = "node-key"
  public_key = var.ec2_ssh_pub_key
}

# Data source to find the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 instance
resource "aws_instance" "node_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.node_key.key_name
  vpc_security_group_ids = [aws_security_group.node_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y docker.io
    usermod -aG docker ubuntu
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    systemctl start docker
    systemctl enable docker
  EOF

  tags = {
    Name = "NodeJS-Docker-Server"
  }
}

# Elastic IP
resource "aws_eip" "node_ip" {
  instance = aws_instance.node_server.id
  domain   = "vpc"
}

output "public_ip" {
  value = aws_eip.node_ip.public_ip
}

output "ssh_connection" {
  value = "ssh -i ~/.ssh/node-key ubuntu@${aws_eip.node_ip.public_ip}"
}