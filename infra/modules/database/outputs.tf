
output "mysql_host" {
  description = "RDS MySQL host"
  value       = split(":", aws_db_instance.mysql.endpoint)[0]
}

output "mysql_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.mysql.port
}

output "mysql_username" {
  description = "RDS MySQL username"
  value       = aws_db_instance.mysql.username
  sensitive   = true
}

output "mysql_database" {
  description = "RDS MySQL database name"
  value       = aws_db_instance.mysql.db_name
}


output "mysql_password" {
  description = "RDS MySQL password"
  value       = random_password.mysql.result
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].port
}

# output "mongodb_endpoint" {
#   description = "MongoDB endpoint"
#   value       = aws_docdb_cluster.mongodb.endpoint
# }

# output "mongodb_port" {
#   description = "MongoDB port"
#   value       = aws_docdb_cluster.mongodb.port
# }

# output "mongodb_username" {
#   description = "MongoDB username"
#   value       = aws_docdb_cluster.mongodb.master_username
#   sensitive   = true
# }

# output "mongodb_password" {
#   description = "MongoDB password"
#   value       = random_password.mongodb.result
#   sensitive   = true
# }






output "mongodb_endpoint" {
  description = "MongoDB private IP address"
  value       = aws_instance.mongodb.private_ip
}


output "mongodb_ec2_public_ip" {
  description = "MongoDB EC2 public IP address"
  value       = aws_instance.mongodb.public_ip
}

output "mongodb_port" {
  description = "MongoDB port"
  value       = 27017
}

output "mongodb_username" {
  description = "MongoDB username"
  value       = "openedx"
}

output "mongodb_password" {
  description = "MongoDB password"
  value       = "Admin123@"
}
