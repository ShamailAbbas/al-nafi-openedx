output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.openedx.id
}

output "efs_access_point_id" {
  description = "EFS access point ID"
  value       = aws_efs_access_point.openedx.id
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.openedx.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.openedx.arn
}

output "s3_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.openedx.bucket_regional_domain_name
}

output "efs_csi_role_arn" {
  description = "EFS CSI driver IAM role ARN"
  value       = aws_iam_role.efs_csi.arn
}