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

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}


variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 50
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.small"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "mongodb_instance_class" {
  description = "MongoDB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "mongodb_instance_count" {
  description = "Number of MongoDB instances"
  type        = number
  default     = 1
}

variable "rds_security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "redis_security_group_id" {
  description = "Security group ID for Redis"
  type        = string
}

variable "mongodb_security_group_id" {
  description = "Security group ID for MongoDB"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the database resources"
  type        = string  
  
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  
}




# variables.tf - Add to your existing variables
variable "mongodb_instance_type" {
  description = "EC2 instance type for MongoDB"
  type        = string
  default     = "t3.medium"
}

variable "mongodb_disk_size" {
  description = "Root disk size for MongoDB in GB"
  type        = number
  default     = 50
}

variable "mongodb_data_disk_size" {
  description = "Data disk size for MongoDB in GB"
  type        = number
  default     = 100
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = ""  # Empty default, will be set in locals
}
