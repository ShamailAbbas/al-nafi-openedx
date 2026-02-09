module "networking" {
  source = "../../modules/networking"

  cluster_name       = var.cluster_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  single_nat_gateway = var.single_nat_gateway
  common_tags        = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.cluster_name
  environment     = var.environment
  vpc_id          = module.networking.vpc_id
  private_subnets = module.networking.private_subnets
  common_tags     = local.common_tags

  kubernetes_version      = var.kubernetes_version
  node_instance_type      = var.node_instance_type
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_group_desired_size = var.node_group_desired_size
}

module "security" {
  source = "../../modules/security"

  cluster_name           = var.cluster_name
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  node_security_group_id = module.eks.node_security_group_id
  cluster_security_group_id = module.eks.cluster_security_group_id
  common_tags            = local.common_tags
  allowed_cidr_blocks    = var.allowed_cidr_blocks

}

module "database" {
  source = "../../modules/database"

  cluster_name    = var.cluster_name
  environment     = var.environment
  private_subnets = module.networking.private_subnets
  public_subnets  = module.networking.public_subnets
  common_tags     = local.common_tags

  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_multi_az          = var.db_multi_az

  redis_node_type       = var.redis_node_type
  redis_num_cache_nodes = var.redis_num_cache_nodes

  mongodb_instance_class = var.mongodb_instance_class
  mongodb_instance_count = var.mongodb_instance_count

  rds_security_group_id     = module.security.rds_security_group_id
  redis_security_group_id   = module.security.redis_security_group_id
  mongodb_security_group_id = module.security.mongodb_security_group_id

  vpc_cidr = var.vpc_cidr
  vpc_id = module.networking.vpc_id
  
}

module "storage" {
  source = "../../modules/storage"

  cluster_name    = var.cluster_name
  namespace = var.namespace
  environment     = var.environment
  private_subnets = module.networking.private_subnets
  common_tags     = local.common_tags

  efs_security_group_id = module.security.efs_security_group_id
  oidc_provider_arn     = module.eks.oidc_provider_arn
  

  depends_on = [ module.eks ]
}

module "search" {
  source = "../../modules/search"

  cluster_name    = var.cluster_name
  environment     = var.environment
  private_subnets = module.networking.private_subnets
  common_tags     = local.common_tags

  elasticsearch_instance_type   = var.elasticsearch_instance_type
  elasticsearch_instance_count  = var.elasticsearch_instance_count
  elasticsearch_volume_size     = var.elasticsearch_volume_size
  elasticsearch_public_access   = var.elasticsearch_public_access
  elasticsearch_master_username = var.elasticsearch_master_username
  elasticsearch_master_password = var.elasticsearch_master_password

  elasticsearch_security_group_id = module.security.elasticsearch_security_group_id
  allowed_cidr_blocks             = var.allowed_cidr_blocks
  domain_name                     = var.domain_name
 
  aws_region                       = var.aws_region
}

# Note: CDN and WAF modules would be added once ALB is created
# They depend on having an Application Load Balancer provisioned

# Local variables
locals {
  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Project     = "OpenEdX"
    ManagedBy   = "Terraform"
    CostCenter  = "Education"
  })
}