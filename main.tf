terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  shared_credentials_file = "var.creds_path.var.creds_file"
  profile = "default"
}

# Create a VPC
resource "aws_vpc" "app_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "app-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "vpc_igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "public_rt_asso" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_instance" "web-search" {
  ami           = "ami-059a9b1093495222c" 
  instance_type = var.instance_type
  key_name = var.instance_key
  subnet_id              = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.sg.id]

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing apache2"
  sudo apt update -y
  sudo apt install apache2 -y
  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
  sudo apt-get install apt-transport-https
  echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
  sudo apt-get update && sudo apt-get install elasticsearch
  action.auto_create_index: .monitoring*,.watches,.triggered_watches,.watcher-history*,.ml*
  sudo /bin/systemctl daemon-reload
  sudo /bin/systemctl enable elasticsearch.service
  sudo systemctl start elasticsearch.service
  sudo systemctl stop elasticsearch.service
  echo "keystore_password" > /path/to/my_pwd_file.tmp
  chmod 600 /path/to/my_pwd_file.tmp
  sudo systemctl set-environment ES_KEYSTORE_PASSPHRASE_FILE=/path/to/my_pwd_file.tmp
  sudo systemctl start elasticsearch.service
  echo "*** Completed Installing apache2 and Elasticsearch"
  EOF

  tags = {
    Name = "web_instance"
  }

  volume_tags = {
    Name = "web_instance"
  } 
}
