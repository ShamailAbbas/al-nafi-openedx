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
node_group_min_size     = 2
node_group_max_size     = 4
node_group_desired_size = 2

# Database Configuration
db_instance_class    = "db.t3.small"
db_allocated_storage = 20
db_multi_az          = false

# Redis Configuration
redis_node_type       = "cache.t3.small"
redis_num_cache_nodes = 1

# MongoDB Configuration
mongodb_instance_class = "db.t3.medium"
mongodb_instance_count = 1

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