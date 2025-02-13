# This is where we define which provider we need (AWS) and the version to use

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
}

# 1. Create a VPC - this is like a private network in AWS
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# 2. Create a Subnet inside the VPC - This is a smaller part of the network where we will put our EC2
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "main-subnet"
  }
}

# 3. Internet Gateway for external access - This allows our network to connect to the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# 4. Route Table to connect Subnet to the Internet - This tells the network where to send traffic
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
}

# Route for internet traffic
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id            = aws_internet_gateway.main.id
}

# Associate the Route Table with the Subnet
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# 5. Create a Security Group - This acts like a firewall for your EC2 instance
resource "aws_security_group" "security_group" {
  vpc_id = aws_vpc.main.id 

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  tags = {
    Name = "security_group"
  }
}

# 6. Create the EC2 Instance - This is the server that will run in your subnet
resource "aws_instance" "app_server" {
  ami           = "ami-085ad6ae776d8f09c"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main.id
  security_groups = [aws_security_group.security_group]

  tags = {
    Name = "SilviaTerraformInstance"
  }
}
resource "random_id" "bucket_id" {
  byte_length = 8
}
# 7. Create an S3 Bucket to store data
resource "aws_s3_bucket" "alzheimers_data" {
  bucket = "alzheimers-prediction-data-bucket-${random_id.bucket_id.hex}"
  
}
resource "aws_iam_role" "ec2_role" {
  name               = "EC2Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_policy" {
  name        = "S3AccessPolicy"
  description = "Allow EC2 instance to access S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:*"
        Resource = "arn:aws:s3:::${aws_s3_bucket.alzheimers_data.bucket}/*"
        Effect   = "Allow"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_policy" {
  policy_arn = aws_iam_policy.s3_policy.arn
  role       = aws_iam_role.ec2_role.name
}
  # 8. Upload Alzheimer’s Prediction Dataset to S3
resource "aws_s3_bucket_object" "alzheimers_data_object" {
  bucket = aws_s3_bucket.alzheimers_data.bucket
  key    = "alzheimers-prediction-data.csv"  # File name in the bucket
  source = "C:/Users/silvia/Downloads/archive/alzheimers_prediction_dataset.csv"   # Path to the local dataset
  acl    = "private"
}