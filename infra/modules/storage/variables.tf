

# Variables - customize these for your deployment
variable "openedx_environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region for S3 buckets"
  type        = string
  default     = "us-east-2"
}

variable "lms_domain" {
  description = "LMS domain (e.g., lms.yourdomain.com)"
  type        = string
  default = "savegb.org"
}

variable "cms_domain" {
  description = "CMS/Studio domain (e.g., studio.yourdomain.com)"
  type        = string
  default = "cms.savegb.org"
}

variable "storage_bucket_name" {
  description = "Name for the private storage bucket"
  type        = string
  default = "storage-bucket"
}

variable "profile_images_bucket_name" {
  description = "Name for the public profile images bucket"
  type        = string
  default = "profile-image-bucket"
}

variable "enable_versioning" {
  description = "Enable versioning on storage bucket"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}