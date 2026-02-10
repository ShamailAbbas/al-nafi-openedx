resource "random_password" "mysql" {
  length           = 32
  special          = true
  override_special = "!#%^_-+"
}

resource "random_password" "mongodb" {
  length           = 32
  special          = true
  override_special = "!#%^_-+"
}

# RDS MySQL
resource "aws_db_subnet_group" "mysql" {
  name       = "${var.cluster_name}-mysql-subnet"
  subnet_ids = var.private_subnets
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-mysql-subnet" })
}

resource "aws_db_parameter_group" "mysql" {
  name_prefix = "${var.cluster_name}-mysql-"
  family      = "mysql8.4"
  description = "Parameter group for Open edX MySQL"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  lifecycle {
    create_before_destroy = true
  }
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-mysql-params" })
}

resource "aws_db_instance" "mysql" {
  identifier = "${var.cluster_name}-mysql"

  engine         = "mysql"
  engine_version = "8.4.3"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "openedx"
  username = "openedx"
  password = random_password.mysql.result
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period = var.environment == "production" ? 14 : 7
  skip_final_snapshot    = var.environment != "production"
  deletion_protection    = var.environment == "production"

  parameter_group_name = aws_db_parameter_group.mysql.name

  tags = merge(var.common_tags, { Name = "${var.cluster_name}-mysql" })
}

# Redis ElastiCache
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.cluster_name}-redis-subnet"
  subnet_ids = var.private_subnets
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-redis-subnet" })
}

resource "aws_elasticache_parameter_group" "redis" {
  name        = "${var.cluster_name}-redis"
  family      = "redis7"
  description = "Parameter group for Open edX Redis"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  lifecycle { create_before_destroy = true }
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-redis-params" })
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.cluster_name}-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_nodes      = var.redis_num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [var.redis_security_group_id]

  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_retention_limit = var.environment == "production" ? 14 : 7
  transit_encryption_enabled = false

  tags = merge(var.common_tags, { Name = "${var.cluster_name}-redis" })
}

# MongoDB 
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
  user_data = file("${path.module}/mongodb_setup.sh")
  
  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-mongodb-instance"
  })
}

