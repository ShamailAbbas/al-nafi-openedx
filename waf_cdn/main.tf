terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Provider for us-east-1 (required for CloudFront certificates and WAF)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Provider for your NLB region (us-east-2)
provider "aws" {
  alias  = "us_east_2"
  region = "us-east-2"
}

# Variables
variable "dns_record_for_nlb" {
  description = "NLB DNS name from kubectl"
  type        = string
  
}

variable "nlb_arn" {
  description = "NLB ARN"
  type        = string
  
}

variable "nlb_dns" {
  description = "NLB DNS"
  type        = string
}


variable "domain_name" {
  description = "Your domain (e.g., savegb.org)"
  type        = string
  default     = "savegb.org"
}

# Random ID for custom header
resource "random_id" "cloudfront_header" {
  byte_length = 8
}

# ACM Certificate in us-east-1 (required for CloudFront)
resource "aws_acm_certificate" "openedx" {
  provider = aws.us_east_1
  
  domain_name       = var.domain_name
  validation_method = "DNS"
  
  subject_alternative_names = [
    "cms.${var.domain_name}",
    "apps.${var.domain_name}"
  ]
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name = "openedx-cloudfront-cert"
  }
}

# Wait for certificate to be issued (it can take a few moments)
resource "time_sleep" "wait_for_certificate" {
  depends_on = [aws_acm_certificate.openedx]
  
  create_duration = "30s"
}

# Custom origin request policy that forwards the Host header
resource "aws_cloudfront_origin_request_policy" "forward_host" {
  provider = aws.us_east_1
  name     = "forward-host-policy-${random_id.cloudfront_header.hex}"
  comment  = "Forwards Host header to origin for Open edX"

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Host", "Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers",
      "Referer",           # Django CSRF validates this on every unsafe method
      "X-CSRFToken",       # The CSRF token itself
      # "X-Forwarded-Proto", # Tells Django the connection was HTTPS (needed for SECURE_PROXY_SSL_HEADER)
      "X-Forwarded-For",   # Real client IP
      # "Authorization",     # JWT tokens for MFE API calls
      "Content-Type",      # Required for JSON API requests
      ]
    }
  }

  cookies_config {
    cookie_behavior = "all"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# WAF Web ACL (must be in us-east-1 for CloudFront)
resource "aws_wafv2_web_acl" "openedx" {
  provider    = aws.us_east_1
  name        = "openedx-waf"
  description = "WAF for Open edX"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "ExemptOpenEdXDynamicEndpoints"
    priority = 0
    action {
      allow {}
    }
    statement {
      or_statement {
        statement {
          byte_match_statement {
            search_string         = "/search/course_discovery/"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "/event"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "/change_enrollment"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ExemptOpenEdXDynamicEndpoints"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Common Rules
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed SQLi Rules
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting (5000 requests per 5 minutes per IP)
  rule {
    name     = "RateLimit"
    priority = 4
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 5000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "openedx-waf"
    sampled_requests_enabled   = true
  }
}

# Get the managed policy IDs dynamically
data "aws_cloudfront_cache_policy" "caching_disabled" {
  provider = aws.us_east_1
  name     = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  provider = aws.us_east_1
  name     = "Managed-CachingOptimized"
}

resource "aws_cloudfront_response_headers_policy" "openedx_security_headers" {
  provider = aws.us_east_1
  name     = "openedx-security-headers"
  comment  = "Security headers for Open edX — allows MFE iframe embedding"

  security_headers_config {
    frame_options {
      frame_option = "SAMEORIGIN"
      override     = false
    }

    content_security_policy {
      content_security_policy = "frame-ancestors 'self' https://savegb.org https://cms.savegb.org https://apps.savegb.org"
      override                = false
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "openedx" {
  provider = aws.us_east_1
  
  depends_on = [time_sleep.wait_for_certificate]
  
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Open edX - ${var.domain_name}"
  default_root_object = ""
  price_class         = "PriceClass_100"  # Use North America/Europe only for cost savings

  # Your custom domains
  aliases = [
    var.domain_name,
    "cms.${var.domain_name}",
    "apps.${var.domain_name}"
  ]

  # Origin: Your NLB (in us-east-2)
  origin {    
    domain_name = var.dns_record_for_nlb  
    origin_id   = "nlb-openedx-origin"

    custom_origin_config {
      http_port                = 80
      https_port               = 443      
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 60
    }

    # Add custom header to identify CloudFront traffic
    custom_header {
      name  = "X-CloudFront-Origin"
      value = random_id.cloudfront_header.hex
    }

  }

  # Default cache behavior (no cache for dynamic content)
  default_cache_behavior {
    target_origin_id       = "nlb-openedx-origin"
    viewer_protocol_policy = "redirect-to-https"
    
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress               = true
    # response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # SecurityHeadersPolicy
    
    response_headers_policy_id = aws_cloudfront_response_headers_policy.openedx_security_headers.id
  }

  # Cache static assets
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400  # 1 day
    max_ttl    = 31536000 # 1 year
  }

  # Cache media files
  ordered_cache_behavior {
    path_pattern     = "/media/*"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  # Cache JavaScript files
  ordered_cache_behavior {
    path_pattern     = "*.js"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  # Cache CSS files
  ordered_cache_behavior {
    path_pattern     = "*.css"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  # Cache image files
  ordered_cache_behavior {
    path_pattern     = "*.png"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "*.jpg"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "*.jpeg"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "*.gif"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "*.svg"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "*.ico"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  # Cache font files
  ordered_cache_behavior {
    path_pattern     = "*.woff"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "*.woff2"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "*.ttf"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "*.eot"
    target_origin_id = "nlb-openedx-origin"
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_host.id
    
    compress = true
    min_ttl = 0
    default_ttl = 86400
    max_ttl    = 31536000
  }

  # SSL Certificate
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.openedx.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # WAF Association
  web_acl_id = aws_wafv2_web_acl.openedx.arn

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name    = "openedx-cloudfront"
    Project = "openedx"
  }
}

# Outputs for Namecheap DNS
output "acm_validation_records" {
  description = "Add these CNAME records to Namecheap for SSL validation"
  value = {
    for dvo in aws_acm_certificate.openedx.domain_validation_options : dvo.domain_name => {
      name  = trimsuffix(dvo.resource_record_name, ".${dvo.domain_name}")
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}



output "dns_records" {
  description = "CNAME records to configure in Namecheap"

  value = {
    "@" = {
      name  = "@"
      type  = "CNAME"
      value = aws_cloudfront_distribution.openedx.domain_name
    }

    apps = {
      name  = "apps"
      type  = "CNAME"
      value = aws_cloudfront_distribution.openedx.domain_name
    }

    cms = {
      name  = "cms"
      type  = "CNAME"
      value = aws_cloudfront_distribution.openedx.domain_name
    }

    lb = {
      name  = "lb"
      type  = "CNAME"
      value = var.nlb_dns
    }
  }
}