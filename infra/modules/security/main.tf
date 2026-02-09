# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.cluster_name}-rds-sg" })
  lifecycle { create_before_destroy = true }
}

# RDS ingress from EKS worker nodes
resource "aws_security_group_rule" "rds_ingress_nodes" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.node_security_group_id
  description              = "MySQL from EKS worker nodes"
}

# RDS ingress from EKS cluster (MISSING IN YOUR CONFIG!)
resource "aws_security_group_rule" "rds_ingress_cluster" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.cluster_security_group_id
  description              = "MySQL from EKS cluster"
}

resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

# Security Group for Redis
resource "aws_security_group" "redis" {
  name_prefix = "${var.cluster_name}-redis-"
  description = "Security group for Redis"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.cluster_name}-redis-sg" })
  lifecycle { create_before_destroy = true }
}

# Redis ingress from EKS worker nodes
resource "aws_security_group_rule" "redis_ingress_nodes" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = var.node_security_group_id
  description              = "Redis from EKS worker nodes"
}

# Redis ingress from EKS cluster (MISSING IN YOUR CONFIG!)
resource "aws_security_group_rule" "redis_ingress_cluster" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = var.cluster_security_group_id
  description              = "Redis from EKS cluster"
}

resource "aws_security_group_rule" "redis_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.redis.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

# Security Group for MongoDB
resource "aws_security_group" "mongodb" {
  name_prefix = "${var.cluster_name}-mongodb-"
  description = "Security group for MongoDB"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.cluster_name}-mongodb-sg" })
  lifecycle { create_before_destroy = true }
}

# MongoDB ingress from EKS worker nodes
resource "aws_security_group_rule" "mongodb_ingress_nodes" {
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mongodb.id
  source_security_group_id = var.node_security_group_id
  description              = "MongoDB from EKS worker nodes"
}

# MongoDB ingress from EKS cluster (MISSING IN YOUR CONFIG!)
resource "aws_security_group_rule" "mongodb_ingress_cluster" {
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mongodb.id
  source_security_group_id = var.cluster_security_group_id
  description              = "MongoDB from EKS cluster"
}

resource "aws_security_group_rule" "mongodb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.mongodb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}


resource "aws_security_group_rule" "mongodb_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.mongodb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "SSH access"
}


# Security Group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "${var.cluster_name}-efs-"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.cluster_name}-efs-sg" })
  lifecycle { create_before_destroy = true }
}

# EFS ingress from EKS worker nodes
resource "aws_security_group_rule" "efs_ingress_nodes" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = var.node_security_group_id
  description              = "NFS from EKS worker nodes"
}

# EFS ingress from EKS cluster (MISSING IN YOUR CONFIG!)
resource "aws_security_group_rule" "efs_ingress_cluster" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = var.cluster_security_group_id
  description              = "NFS from EKS cluster"
}

resource "aws_security_group_rule" "efs_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.efs.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

# Security Group for OpenSearch
resource "aws_security_group" "elasticsearch" {
  name_prefix = "${var.cluster_name}-es-"
  description = "Security group for OpenSearch"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.cluster_name}-elasticsearch-sg" })
  lifecycle { create_before_destroy = true }
}

# OpenSearch ingress from EKS worker nodes
resource "aws_security_group_rule" "elasticsearch_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticsearch.id
  source_security_group_id = var.node_security_group_id
  description              = "HTTPS from EKS worker nodes"
}

# OpenSearch ingress from EKS cluster (MISSING IN YOUR CONFIG!)
resource "aws_security_group_rule" "elasticsearch_ingress_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticsearch.id
  source_security_group_id = var.cluster_security_group_id
  description              = "HTTPS from EKS cluster"
}

resource "aws_security_group_rule" "elasticsearch_public_ingress" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.elasticsearch.id
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "HTTPS from allowed CIDR blocks"
}

resource "aws_security_group_rule" "elasticsearch_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.elasticsearch.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}
