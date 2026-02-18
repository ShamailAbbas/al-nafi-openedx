
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


