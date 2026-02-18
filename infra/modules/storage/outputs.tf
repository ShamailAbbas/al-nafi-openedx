# Outputs
output "storage_bucket_name" {
  description = "Name of the storage bucket"
  value       = aws_s3_bucket.openedx_storage.id
}

# output "storage_bucket_arn" {
#   description = "ARN of the storage bucket"
#   value       = aws_s3_bucket.openedx_storage.arn
# }

# output "profile_images_bucket_name" {
#   description = "Name of the profile images bucket"
#   value       = aws_s3_bucket.openedx_profile_images.id
# }

# output "profile_images_bucket_arn" {
#   description = "ARN of the profile images bucket"
#   value       = aws_s3_bucket.openedx_profile_images.arn
# }

# output "iam_user_name" {
#   description = "Name of the IAM user"
#   value       = aws_iam_user.openedx_s3_user.name
# }

# output "iam_user_arn" {
#   description = "ARN of the IAM user"
#   value       = aws_iam_user.openedx_s3_user.arn
# }

output "aws_access_key_id" {
  description = "AWS Access Key ID for the IAM user"
  value       = aws_iam_access_key.openedx_s3_user_key.id
  sensitive   = true
}

output "aws_secret_access_key" {
  description = "AWS Secret Access Key for the IAM user"
  value       = aws_iam_access_key.openedx_s3_user_key.secret
  sensitive   = true
}

# output "tutor_configuration_commands" {
#   description = "Commands to configure Tutor with these S3 resources"
#   value = <<-EOT
#     # Run these commands to configure Tutor:
#     tutor plugins install s3
#     tutor plugins enable s3
#     tutor config save --set OPENEDX_AWS_ACCESS_KEY="${aws_iam_access_key.openedx_s3_user_key.id}"
#     tutor config save --set OPENEDX_AWS_SECRET_ACCESS_KEY="${aws_iam_access_key.openedx_s3_user_key.secret}"
#     tutor config save --set S3_REGION="${var.aws_region}"
#     tutor config save --set S3_STORAGE_BUCKET="${aws_s3_bucket.openedx_storage.id}"
#     tutor config save --set S3_PROFILE_IMAGE_BUCKET="${aws_s3_bucket.openedx_profile_images.id}"
#     tutor config save --set S3_GRADE_BUCKET="${aws_s3_bucket.openedx_storage.id}"
#     tutor config save --set S3_FILE_UPLOAD_BUCKET="${aws_s3_bucket.openedx_storage.id}"
#     tutor config save --set S3_ADDRESSING_STYLE="auto"
#     tutor config save --set S3_CUSTOM_DOMAIN=""
#     tutor k8s stop
#     tutor k8s start
#   EOT
#   sensitive = true
# }
