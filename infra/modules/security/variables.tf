variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "node_security_group_id" {
  description = "EKS node security group ID"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "Allowed CIDR blocks for public access"
  type        = list(string)
  default     = []
}

variable "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  type        = string
}

