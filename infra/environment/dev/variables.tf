variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Cluster name"
  type        = string
  default     = "openedx-dev"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "namespace" {
  description = "Kubernetes namespace for OpenEdX components"
  type        = string
  default     = "openedx"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.1.0.0/16"
}

variable "private_subnets" {
  description = "Private subnets"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "public_subnets" {
  description = "Public subnets"
  type        = list(string)
  default     = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway"
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "Node instance type"
  type        = string
  default     = "t3.medium"
}

variable "node_group_min_size" {
  description = "Node group min size"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Node group max size"
  type        = number
  default     = 4
}

variable "node_group_desired_size" {
  description = "Node group desired size"
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "RDS multi-AZ"
  type        = bool
  default     = false
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.small"
}

variable "redis_num_cache_nodes" {
  description = "Redis number of cache nodes"
  type        = number
  default     = 1
}

variable "mongodb_instance_class" {
  description = "MongoDB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "mongodb_instance_count" {
  description = "MongoDB instance count"
  type        = number
  default     = 1
}





variable "elasticsearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search"
}

variable "elasticsearch_instance_count" {
  description = "OpenSearch instance count"
  type        = number
  default     = 1
}

variable "elasticsearch_volume_size" {
  description = "OpenSearch volume size"
  type        = number
  default     = 20
}

variable "elasticsearch_public_access" {
  description = "OpenSearch public access"
  type        = bool
  default     = true
}

variable "elasticsearch_master_username" {
  description = "OpenSearch master username"
  type        = string
  default     = "admin"
}

variable "elasticsearch_master_password" {
  description = "OpenSearch master password"
  type        = string
  default     = "Admin123!"
  
}

variable "allowed_cidr_blocks" {
  description = "Allowed CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "dev.openedx.example.com"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}