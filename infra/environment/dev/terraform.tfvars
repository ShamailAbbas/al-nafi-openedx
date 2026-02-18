aws_region   = "us-east-2"
environment  = "dev"
cluster_name = "openedx-dev"
namespace    = "openedx"


# VPC Configuration
vpc_cidr           = "10.1.0.0/16"
private_subnets    = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
public_subnets     = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
single_nat_gateway = true

# EKS Configuration
kubernetes_version      = "1.31"
node_instance_type      = "t3.medium"
node_group_min_size     = 8
node_group_max_size     = 16
node_group_desired_size = 10

# Database Configuration
db_instance_class    = "db.t3.small"
db_allocated_storage = 20
db_multi_az          = false

# Redis Configuration
redis_node_type       = "cache.t3.small"
redis_num_cache_nodes = 1


# OpenSearch Configuration
elasticsearch_instance_type   = "t3.small.search"
elasticsearch_instance_count  = 2
elasticsearch_volume_size     = 20
elasticsearch_public_access   = true
elasticsearch_master_username = "admin"
elasticsearch_master_password = "Admin123!"
allowed_cidr_blocks           = ["0.0.0.0/0"]

# Domain Configuration
domain_name         = "openedx-dev"


# Additional Tags
common_tags = {
  Project    = "OpenEdX"
  ManagedBy  = "Terraform"
  CostCenter = "Education"
  Owner      = "DevOps Team"
}

acm_certificate_arn = "arn:aws:acm:us-east-1:975148381826:certificate/9815cb38-3ded-464a-a525-5189c2e39d7f"

nlb_dns_name = "lb.savegb.org"