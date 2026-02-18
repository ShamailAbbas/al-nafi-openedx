# ============================================================
# Get current AWS account ID
# ============================================================

data "aws_caller_identity" "current" {}

resource "random_uuid" "uuid" {}

# ============================================================
# IAM USER FOR OPENEDX
# ============================================================

resource "aws_iam_user" "openedx_s3_user" {
  name = "openedx-s3-user-${var.openedx_environment}"
  path = "/openedx/"

  tags = {
    Name        = "Open edX S3 User"
    Environment = var.openedx_environment
    ManagedBy   = "Terraform"
  }
}

# Access Key
resource "aws_iam_access_key" "openedx_s3_user_key" {
  user = aws_iam_user.openedx_s3_user.name
}

# ============================================================
# FULL S3 ACCESS (ALL BUCKETS + CREATE BUCKET)
# ============================================================

resource "aws_iam_user_policy_attachment" "openedx_s3_full_access" {
  user       = aws_iam_user.openedx_s3_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# ============================================================
# PRIVATE STORAGE BUCKET
# ============================================================

resource "aws_s3_bucket" "openedx_storage" {
  bucket = "${var.storage_bucket_name}-${random_uuid.uuid.result}"

  tags = {
    Name        = "Open edX Storage Bucket"
    Environment = var.openedx_environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_ownership_controls" "openedx_storage" {
  bucket = aws_s3_bucket.openedx_storage.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "openedx_storage" {
  bucket = aws_s3_bucket.openedx_storage.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_versioning" "openedx_storage" {
  bucket = aws_s3_bucket.openedx_storage.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "openedx_storage" {
  bucket = aws_s3_bucket.openedx_storage.id

  cors_rule {
    allowed_headers = [
      "Content-disposition",
      "Content-type",
      "X-CSRFToken"
    ]
    allowed_methods = [
      "GET",
      "PUT"
    ]
    allowed_origins = ["*"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}

# ============================================================
# PUBLIC PROFILE IMAGES BUCKET
# ============================================================

# resource "aws_s3_bucket" "openedx_profile_images" {
#   bucket = "${var.profile_images_bucket_name}-${random_uuid.uuid.result}"

#   tags = {
#     Name        = "Open edX Profile Images Bucket"
#     Environment = var.openedx_environment
#     ManagedBy   = "Terraform"
#   }
# }

# resource "aws_s3_bucket_ownership_controls" "openedx_profile_images" {
#   bucket = aws_s3_bucket.openedx_profile_images.id
#   rule {
#     object_ownership = "BucketOwnerEnforced"
#   }
# }

# resource "aws_s3_bucket_public_access_block" "openedx_profile_images" {
#   bucket = aws_s3_bucket.openedx_profile_images.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket_versioning" "openedx_profile_images" {
#   bucket = aws_s3_bucket.openedx_profile_images.id

#   versioning_configuration {
#     status = "Disabled"
#   }
# }

# resource "aws_s3_bucket_policy" "openedx_profile_images" {
#   bucket = aws_s3_bucket.openedx_profile_images.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid       = "openedxWebAccess"
#         Effect    = "Allow"
#         Principal = "*"
#         Action    = "s3:GetObject"
#         Resource  = "${aws_s3_bucket.openedx_profile_images.arn}/*"
#       }
#     ]
#   })

#   depends_on = [
#     aws_s3_bucket_public_access_block.openedx_profile_images
#   ]
# }

# resource "aws_s3_bucket_cors_configuration" "openedx_profile_images" {
#   bucket = aws_s3_bucket.openedx_profile_images.id

#   cors_rule {
#     allowed_headers = []
#     allowed_methods = [
#       "GET",
#       "PUT"
#     ]
#     allowed_origins = ["*"]
#     expose_headers  = []
#     max_age_seconds = 3000
#   }
# }
