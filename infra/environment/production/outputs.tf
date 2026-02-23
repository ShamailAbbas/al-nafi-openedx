output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}


output "cluster_autoscaler_role_arn" {
  description = "cluster autoscaler arn"
  value = module.eks.cluster_autoscaler_role_arn
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




output "storage_bucket_name" {
  description = "S3 Storage bucket name"
  value       = module.storage.storage_bucket_name
}




output "aws_access_key_id" {
  description = "AWS Access Key ID for the IAM user"
  value       = module.storage.aws_access_key_id
  sensitive   = true
}


output "aws_secret_access_key" {
  description = "AWS Secret Access Key for the IAM user"
  value       = module.storage.aws_secret_access_key
  sensitive   = true
}



output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}


# output "cloudfront_domain_name" {
#   description = "Use this in Namecheap CNAME records"
#   value       = module.waf-cdn.cloudfront_domain_name
# }

