output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}


output "mysql_host" {
  description = "MySQL host"
  value       = module.database.mysql_host
}

output "mysql_username" {
  description = "MySQL user"
  value       = module.database.mysql_username
  sensitive   = true
}



output "mysql_database" {
  description = "RDS MySQL database name"
  value       = module.database.mysql_database
}


output "mysql_port" {
  description = "RDS MySQL port"
  value       = module.database.mysql_port
}

output "mysql_password" {
  description = "MySQL password"
  value       = module.database.mysql_password
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.database.redis_endpoint
}

output "redis_port" {
  description = "Redis port"
  value       = module.database.redis_port
}

output "mongodb_endpoint" {
  description = "MongoDB endpoint"
  value       = module.database.mongodb_endpoint
}

output "mongodb_ec2_public_ip" {
  description = "MongoDB EC2 public IP address"
  value       = module.database.mongodb_ec2_public_ip
}

output "mongodb_port" {
  description = "MongoDB port"
  value       = module.database.mongodb_port
}

output "mongodb_username" {
  description = "MongoDB username"
  value       = module.database.mongodb_username
  sensitive   = true
}

output "mongodb_password" {
  description = "MongoDB password"
  value       = module.database.mongodb_password
  sensitive   = true
}





output "elasticsearch_endpoint" {
  description = "OpenSearch endpoint"
  value       = module.search.elasticsearch_endpoint
}

output "elasticsearch_kibana_endpoint" {
  description = "OpenSearch Kibana endpoint"
  value       = module.search.elasticsearch_kibana_endpoint
}

output "elasticsearch_master_username" {
  description = "OpenSearch master username"
  value       = module.search.elasticsearch_master_username
  sensitive   = true
}

output "elasticsearch_master_password" {
  description = "OpenSearch master password"
  value       = module.search.elasticsearch_master_password
  sensitive   = true
}

# output "efs_id" {
#   description = "EFS ID"
#   value       = module.storage.efs_id
# }

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.storage.s3_bucket_name
}

# output "vpc_id" {
#   description = "VPC ID"
#   value       = module.networking.vpc_id
# }

# output "private_subnets" {
#   description = "Private subnets"
#   value       = module.networking.private_subnets
# }

# output "public_subnets" {
#   description = "Public subnets"
#   value       = module.networking.public_subnets
# }

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

