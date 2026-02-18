output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "Redis security group ID"
  value       = aws_security_group.redis.id
}


output "elasticsearch_security_group_id" {
  description = "OpenSearch security group ID"
  value       = aws_security_group.elasticsearch.id
}