provider "aws" {
  region = "ap-south-1"
}

#Get my IP
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

#VPC etc
resource "aws_vpc" "do_it_easy_vpc"  {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "do_it_easy_vpc"
  }
}

resource "aws_internet_gateway" "do_it_easy_gw" {
  vpc_id = aws_vpc.do_it_easy_vpc.id
  tags = {
    Name = "MyGW"
  }
}

resource "aws_subnet" "pubsub1" {
  vpc_id = aws_vpc.do_it_easy_vpc.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
  tags = {
    Name = "Pubsub1"
  }
}

resource "aws_subnet" "pubsub2" {
  vpc_id = aws_vpc.do_it_easy_vpc.id
  cidr_block = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1b"
  tags = {
    Name = "Pubsub2"
  } 
}

resource "aws_route_table" "pubsub_routing" {
  vpc_id = aws_vpc.do_it_easy_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.do_it_easy_gw.id
  }

  tags = {
    Name = "PubsubRouting"
  }
}

resource "aws_route_table_association" "pubsub1_ass" {
  subnet_id      = aws_subnet.pubsub1.id
  route_table_id = aws_route_table.pubsub_routing.id
}

resource "aws_route_table_association" "pubsub2_ass" {
  subnet_id      = aws_subnet.pubsub2.id
  route_table_id = aws_route_table.pubsub_routing.id
}

#Security group

resource "aws_security_group" "do_it_easy_sg" {
  name        = "do_it_easy_sg"
  description = "Allow SSH and port 3000 inbound"
  vpc_id      = aws_vpc.do_it_easy_vpc.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
  }

  ingress {
    description = "App port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "do_it_easy_sg"
  }
}

#Setting up the instances

resource "aws_instance" "comp1" {
  ami           = "ami-053b12d3152c0cc71" 
  instance_type = "t3a.micro"
  subnet_id     = aws_subnet.pubsub1.id
# key_name      = "do I need one?" 

  vpc_security_group_ids = [aws_security_group.do_it_easy_sg.id]
  # User Data to run the script when the instance starts
  user_data = <<-EOF
              #!/bin/bash
              apt update &&  apt install -y unzip
              apt-get install -y \
                  apt-transport-https \
                  ca-certificates \
                  curl \
                  software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt update && apt install -y docker-ce docker-ce-cli containerd.io

              systemctl enable docker
              systemctl start docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "comp1"
  }
}
resource "aws_instance" "comp2" {
  ami           = "ami-053b12d3152c0cc71" 
  instance_type = "t3a.micro"
  subnet_id     = aws_subnet.pubsub2.id
# key_name      = "do I need one?" 

  vpc_security_group_ids = [aws_security_group.do_it_easy_sg.id]
  # docker install
  user_data = <<-EOF
              #!/bin/bash
              apt update &&  apt install -y unzip
              apt-get install -y \
                  apt-transport-https \
                  ca-certificates \
                  curl \
                  software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt update && apt install -y docker-ce docker-ce-cli containerd.io

              systemctl enable docker
              systemctl start docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "comp2"
  }
}
