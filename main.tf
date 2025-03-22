provider "aws" {
  region = "us-east-1"  # Change this to your desired AWS region
}

# Fetch default VPC ID
data "aws_vpc" "default" {
  default = true
}

# Fetch all subnets and pick the first one
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "public" {
  id = tolist(data.aws_subnets.public_subnets.ids)[0]
}

# Create Security Group in the default VPC
resource "aws_security_group" "example_sg" {
  name        = "example-security-group"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = data.aws_vpc.default.id  # Attach to default VPC

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allows SSH access from any IP (Not recommended for production)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allows HTTP traffic from any IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "example_keypair" {
  key_name   = "example-keypair"
  public_key = file("~/.ssh/id_rsa.pub")  # Replace with the path to your public key file
}

resource "aws_instance" "example_instance" {
  ami           = "ami-08b5b3a93ed654d19"  # Specify your desired AMI ID
  instance_type = "t2.micro"
  key_name      = aws_key_pair.example_keypair.key_name

  vpc_security_group_ids      = [aws_security_group.example_sg.id]  # Reference the created security group
  subnet_id                   = data.aws_subnet.public.id  # Ensure instance is in a public subnet
  associate_public_ip_address = true  # Assign a public IP

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF
}

output "public_ip" {
  value = aws_instance.example_instance.public_ip
}
