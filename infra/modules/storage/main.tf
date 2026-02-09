# EFS File System
resource "aws_efs_file_system" "openedx" {
  creation_token   = "${var.cluster_name}-openedx-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-openedx-efs"
  })
}

# EFS Mount Targets
resource "aws_efs_mount_target" "openedx" {
  count = length(var.private_subnets)

  file_system_id  = aws_efs_file_system.openedx.id
  subnet_id       = var.private_subnets[count.index]
  security_groups = [var.efs_security_group_id]
}

# EFS Access Point
resource "aws_efs_access_point" "openedx" {
  file_system_id = aws_efs_file_system.openedx.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/openedx"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-openedx-access-point"
  })
}

# IAM role for EFS CSI driver
resource "aws_iam_role" "efs_csi" {
  name_prefix = "${var.cluster_name}-efs-csi-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
        }
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi.name
}

# S3 Bucket
# resource "aws_s3_bucket" "openedx" {
#   bucket_prefix = "${var.cluster_name}-openedx-"

#   tags = merge(var.common_tags, {
#     Name = "${var.cluster_name}-openedx-media"
#   })
# }

# resource "aws_s3_bucket_versioning" "openedx" {
#   bucket = aws_s3_bucket.openedx.id
#   versioning_configuration { status = "Enabled" }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "openedx" {
#   bucket = aws_s3_bucket.openedx.id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# resource "aws_s3_bucket_public_access_block" "openedx" {
#   bucket = aws_s3_bucket.openedx.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket_cors_configuration" "openedx" {
#   bucket = aws_s3_bucket.openedx.id

#   cors_rule {
#     allowed_headers = ["*"]
#     allowed_methods = ["GET", "HEAD", "PUT", "POST", "DELETE"]
#     allowed_origins = ["*"]
#     expose_headers  = ["ETag"]
#     max_age_seconds = 3000
#   }
# }

# resource "aws_s3_bucket_policy" "openedx" {
#   bucket = aws_s3_bucket.openedx.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Sid       = "PublicReadGetObject"
#       Effect    = "Allow"
#       Principal = "*"
#       Action    = "s3:GetObject"
#       Resource  = "${aws_s3_bucket.openedx.arn}/*"
#     }]
#   })
# }




# S3 Bucket for OpenEdX media files
resource "aws_s3_bucket" "openedx" {
  bucket_prefix = "${var.cluster_name}-openedx-"

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-openedx-media"
  })
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "openedx" {
  bucket = aws_s3_bucket.openedx.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "openedx" {
  bucket = aws_s3_bucket.openedx.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "openedx" {
  bucket = aws_s3_bucket.openedx.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket CORS configuration
resource "aws_s3_bucket_cors_configuration" "openedx" {
  bucket = aws_s3_bucket.openedx.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 Bucket policy for public read access
resource "aws_s3_bucket_policy" "openedx" {
  bucket = aws_s3_bucket.openedx.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.openedx.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.openedx]
}

# IAM role for S3 access from EKS
resource "aws_iam_role" "s3_access" {
  name_prefix = "${var.cluster_name}-s3-access-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${var.namespace}:openedx"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags

  
}

# IAM policy for S3 bucket access
resource "aws_iam_role_policy" "s3_access" {
  name_prefix = "${var.cluster_name}-s3-policy-"
  role        = aws_iam_role.s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.openedx.arn,
          "${aws_s3_bucket.openedx.arn}/*"
        ]
      }
    ]
  })
}
