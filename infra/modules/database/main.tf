resource "random_password" "mysql" {
  length           = 32
  special          = true
  override_special = "!#%^_-+=@"
}

resource "random_password" "mongodb" {
  length           = 32
  special          = true
  override_special = "!#%^_-+=@"
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

# MongoDB DocumentDB
resource "aws_docdb_subnet_group" "mongodb" {
  name       = "${var.cluster_name}-mongodb-subnet"
  subnet_ids = var.private_subnets
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-mongodb-subnet" })
}

resource "aws_docdb_cluster" "mongodb" {
  cluster_identifier      = "${var.cluster_name}-mongodb"
  engine                 = "docdb"
  engine_version         = "5.0.0"
  master_username        = "openedx"
  master_password        = random_password.mongodb.result
  db_subnet_group_name   = aws_docdb_subnet_group.mongodb.name
  vpc_security_group_ids = [var.mongodb_security_group_id]
  port                   = 27017
  
  storage_encrypted      = true
  backup_retention_period = var.environment == "production" ? 14 : 7
  skip_final_snapshot    = var.environment != "production"
  deletion_protection    = var.environment == "production"
  
  tags = merge(var.common_tags, { Name = "${var.cluster_name}-mongodb-cluster" })
}

resource "aws_docdb_cluster_instance" "mongodb" {
  count              = var.mongodb_instance_count
  identifier         = "${var.cluster_name}-mongodb-${count.index}"
  cluster_identifier = aws_docdb_cluster.mongodb.id
  instance_class     = var.mongodb_instance_class
  
  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-mongodb-instance-${count.index}"
  })
}