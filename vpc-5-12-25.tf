# VPC
resource "aws_vpc" "food-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "food-vpc"
  }
}

# SUBNETS
resource "aws_subnet" "food-public-subnet" {
  vpc_id     = aws_vpc.food-vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
  tags = {
    Name = "food-public-subnet"
  }
}

# INTERNET GATEWAY
resource "aws_internet_gateway" "food-IGW" {
  vpc_id = aws_vpc.food-vpc.id
  tags = {
    Name = "food-IGW"
  }
}


# ROUTE TABLES

# Public-RT
resource "aws_route_table" "food-public-RT" {
  vpc_id = aws_vpc.food-vpc.id

  route {
    cidr_block           = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.food-IGW.id
  }

  tags = {
    Name = "food-public-RT"
  }
}


# SUBNET - ROUTE TABLE ASSOCIATION -PUBLIC
resource "aws_route_table_association" "food-public-asc" {
  subnet_id      = aws_subnet.food-public-subnet.id
  route_table_id = aws_route_table.food-public-RT.id
}


# Security Groups

# food-Ansible-Master-Security Group
resource "aws_security_group" "food-Ansible-Master-Security-Group" {
  name        = "food-Ansible-Master-Security-Group"
  description = "Allow SSH-HTTP inbound traffic"
  vpc_id      = aws_vpc.food-vpc.id

  ingress {
    description = "SSH from WWW"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from WWW"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "food-Ansible-Master-Security Group"
  }
}

# food-Ansible-Node-Security Group
resource "aws_security_group" "food-Ansible-Node-Security-Group" {
  name        = "food-Ansible-Node-Security-Group"
  description = "Allow SSH-HTTP inbound traffic"
  vpc_id      = aws_vpc.food-vpc.id

  ingress {
    description = "SSH from WWW"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["10.0.1.10/32"]
  }

  ingress {
    description = "HTTP from WWW"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "food-Ansible-Node-Security Group"
  }
}

# Provisioning of Ansible Master (public) and Node (private)
resource "aws_instance" "food-Ansible-Master" {
  ami           = "ami-0d0f28110d16ee7d6"
  instance_type = "t2.medium"
  key_name               = "devops_1"
  vpc_security_group_ids = [aws_security_group.food-Ansible-Master-Security-Group.id]
  private_ip             = "10.0.1.10"
  subnet_id              = aws_subnet.food-public-subnet.id
  metadata_options {
    http_tokens = "optional" # allow user_data without requiring IMDSv2
  }

  user_data = <<-EOF
                #!/bin/bash
                exec > /var/log/user-data.log 2>&1

                yum -y update
                yum -y install git
                yum -y install ansible

                # Ensure target directory exists
                mkdir -p /home/ec2-user
                cd /home/ec2-user
                pwd >> /var/log/user-data.log

                # Clone directly into known path (not relative)
                # git clone https://github.com/Ayoyinka2456/Ansible-FoodApp.git /home/ec2-user/Ansible-FoodApp
                [ -d /home/ec2-user/Ansible-FoodApp ] || git clone https://github.com/Ayoyinka2456/Ansible-FoodApp.git /home/ec2-user/Ansible-FoodApp
                # Set proper ownership
                chown -R ec2-user:ec2-user /home/ec2-user/Ansible-FoodApp

                # Check if directory exists
                if [ -d "/home/ec2-user/Ansible-FoodApp" ]; then
                cd /home/ec2-user/Ansible-FoodApp
                chmod 400 devops_1.pem
                echo "Successfully changed into the directory Ansible-FoodApp" >> /var/log/user-data.log
                ansible -m ping -i host.ini n1 >> /var/log/user-data.log 2>&1
                ansible-playbook setup_food.yml -i host.ini >> /var/log/user-data.log 2>&1
                else
                echo "Directory Ansible-FoodApp does not exist." >> /var/log/user-data.log
                fi
            EOF

  tags = {
    Name = "food Ansible Master"
  }
}

resource "aws_instance" "food-Ansible-Node_1" {
  ami           = "ami-0d0f28110d16ee7d6"
  instance_type = "t2.medium"
  private_ip    = "10.0.1.20"
  subnet_id     = aws_subnet.food-public-subnet.id
  key_name      = "devops_1"
  vpc_security_group_ids = [aws_security_group.food-Ansible-Node-Security-Group.id]

  tags = {
    Name = "food Ansible Node"
  }
}

