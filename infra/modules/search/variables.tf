variable "aws_region" {
  description = "AWS region for the resources"
  type        = string
  default     = "us-east-2"
  
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "elasticsearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search"
}

variable "elasticsearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 1
}

variable "elasticsearch_volume_size" {
  description = "OpenSearch EBS volume size in GB"
  type        = number
  default     = 20
}

variable "elasticsearch_public_access" {
  description = "Enable public access to OpenSearch"
  type        = bool
  default     = false
}

variable "elasticsearch_security_group_id" {
  description = "Security group ID for OpenSearch"
  type        = string
}

variable "elasticsearch_master_username" {
  description = "Master username for OpenSearch"
  type        = string
  default     = "admin"
}



variable "elasticsearch_master_password" {
  description = "Master password for OpenSearch"
  type        = string
   default     = "admin"
}

variable "allowed_cidr_blocks" {
  description = "Allowed CIDR blocks for public access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "domain_name" {
  description = "Domain name for custom endpoint"
  type        = string
  default     = ""
}

