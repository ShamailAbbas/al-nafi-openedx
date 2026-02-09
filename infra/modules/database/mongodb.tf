locals {
  # Expand the path properly
  ssh_public_key_path = var.ssh_public_key_path != "" ? var.ssh_public_key_path : pathexpand("~/.ssh/id_rsa.pub")
}

# Create SSH key pair
resource "aws_key_pair" "mongodb" {
  key_name   = "${var.cluster_name}-mongodb-key"
  public_key = fileexists(local.ssh_public_key_path) ? file(local.ssh_public_key_path) : tls_private_key.mongodb[0].public_key_openssh
  
  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-mongodb-key"
  })
}

# Generate SSH key if file doesn't exist
resource "tls_private_key" "mongodb" {
  count = fileexists(local.ssh_public_key_path) ? 0 : 1
  
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save generated private key
resource "local_file" "generated_private_key" {
  count = fileexists(local.ssh_public_key_path) ? 0 : 1
  
  content  = tls_private_key.mongodb[0].private_key_pem
  filename = "${path.module}/generated_mongodb_key.pem"
  file_permission = "0600"
}

# MongoDB Security Group
resource "aws_security_group" "mongodb" {
  name        = "${var.cluster_name}-mongodb-sg"
  description = "Security group for MongoDB instance"
  vpc_id      = var.vpc_id
  
  # SSH access (restrict to your IP in production)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # CHANGE THIS to your IP in production
  }
  
  # MongoDB from EKS cluster
  ingress {
    description = "MongoDB from EKS"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Only from VPC
  }
  
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-mongodb-sg"
  })
}

# Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# MongoDB EC2 Instance
resource "aws_instance" "mongodb" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.mongodb_instance_type
  key_name               = aws_key_pair.mongodb.key_name
  vpc_security_group_ids = [aws_security_group.mongodb.id]
  subnet_id              = var.public_subnets[0]  # Place in public subnet for SSH access, or private if using VPN/bastion

  associate_public_ip_address = true  # Set to false if you don't want a public IP (requires VPN or bastion host)
  
  # Root disk
  root_block_device {
    volume_size = var.mongodb_disk_size
    volume_type = "gp3"
    encrypted   = true
    
    tags = merge(var.common_tags, {
      Name = "${var.cluster_name}-mongodb-root"
    })
  }
  
  # User data - Simplified MongoDB installation
  user_data = templatefile("${path.module}/mongodb_setup.sh", {
   
  })
  
  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-mongodb-instance"
  })
}

