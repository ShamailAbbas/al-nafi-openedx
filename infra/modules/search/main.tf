data "aws_caller_identity" "current" {}

resource "random_password" "opensearch_master" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# OpenSearch Domain
resource "aws_opensearch_domain" "openedx" {
  domain_name    = "${var.cluster_name}-es"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type  = var.elasticsearch_instance_type
    instance_count = var.elasticsearch_instance_count

    dedicated_master_enabled = var.elasticsearch_instance_count >= 3
    zone_awareness_enabled   = var.elasticsearch_instance_count > 1

    zone_awareness_config {
      availability_zone_count = min(var.elasticsearch_instance_count, 3)
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.elasticsearch_volume_size
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }

  # Network: VPC or public
  dynamic "vpc_options" {
    for_each = var.elasticsearch_public_access ? [] : [1]
    content {
      subnet_ids         = slice(var.private_subnets, 0, min(var.elasticsearch_instance_count, 3))
      security_group_ids = [var.elasticsearch_security_group_id]
    }
  }

  # Endpoint options (HTTPS enforced, TLS policy)
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # Fine-grained access control
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.elasticsearch_master_username
      master_user_password = var.elasticsearch_master_password
    }
  }

  # Encryption
  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  # Access policies
 access_policies = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Allow"
      Principal = { AWS = "*" }
      Action = "es:*"
      Resource = "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.cluster_name}-es/*"
      Condition = {
        IpAddress = {
          "aws:SourceIp" = var.allowed_cidr_blocks
        }
      }
    }
  ]
})


  # Advanced options
  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
    "override_main_response_version"         = "false"
    "indices.fielddata.cache.size"           = ""
    "indices.query.bool.max_clause_count"    = "1024"
  }


  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-opensearch"
  })
}




