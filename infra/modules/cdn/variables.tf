variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "domain_name" {
  description = "Domain name for CloudFront distribution"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name for CloudFront origin"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront"
  type        = string
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "enable_security_headers" {
  description = "Enable security headers via CloudFront function"
  type        = bool
  default     = true
}

variable "cloudfront_logs_bucket" {
  description = "S3 bucket for CloudFront logs"
  type        = string
  default     = ""
}