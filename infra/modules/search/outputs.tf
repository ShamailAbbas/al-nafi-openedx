output "elasticsearch_endpoint" {
  description = "OpenSearch endpoint"
  value       = aws_opensearch_domain.openedx.endpoint
}

output "elasticsearch_domain_id" {
  description = "OpenSearch domain ID"
  value       = aws_opensearch_domain.openedx.domain_id
}

output "elasticsearch_kibana_endpoint" {
  description = "OpenSearch Kibana endpoint"
  value       = aws_opensearch_domain.openedx.kibana_endpoint
}

output "elasticsearch_master_username" {
  description = "OpenSearch master username"
  value       = var.elasticsearch_master_username
  sensitive   = true
}

output "elasticsearch_master_password" {
  description = "OpenSearch master password"
  value       = var.elasticsearch_master_password
  sensitive   = true
}

