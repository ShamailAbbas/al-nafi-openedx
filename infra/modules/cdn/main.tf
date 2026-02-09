# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "openedx" {
  comment = "OpenEdX S3 access identity"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "openedx" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "OpenEdX CDN - ${var.cluster_name}"
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  
  aliases = [var.domain_name]

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "${var.cluster_name}-alb"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  # S3 origin for media files
  origin {
    domain_name = var.s3_bucket_regional_domain_name
    origin_id   = "${var.cluster_name}-s3"
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.openedx.cloudfront_access_identity_path
    }
  }
  
  default_cache_behavior {
    target_origin_id       = "${var.cluster_name}-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    
    forwarded_values {
      query_string = true
      headers      = ["*"]
      
      cookies {
        forward = "all"
      }
    }
    
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
    compress    = true
    
    # Function associations
    dynamic "function_association" {
      for_each = var.enable_security_headers ? [1] : []
      content {
        event_type   = "viewer-response"
        function_arn = aws_cloudfront_function.security_headers[0].arn
      }
    }
  }
  
  # Cache behavior for S3 media files
  ordered_cache_behavior {
    path_pattern     = "/media/*"
    target_origin_id = "${var.cluster_name}-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    
    forwarded_values {
      query_string = false
      headers      = ["Origin"]
      
      cookies {
        forward = "none"
      }
    }
    
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
    compress    = true
  }
  
  # Cache behavior for static files
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    target_origin_id = "${var.cluster_name}-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    
    forwarded_values {
      query_string = false
      
      cookies {
        forward = "none"
      }
    }
    
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
    compress    = true
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  
  # Custom error responses
  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
  }
  
  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 500
    response_code         = 500
    response_page_path    = "/500.html"
  }
  
  logging_config {
    include_cookies = false
    bucket          = var.cloudfront_logs_bucket
    prefix          = "${var.cluster_name}/"
  }
  
  tags = var.common_tags
}

# CloudFront Function for security headers
resource "aws_cloudfront_function" "security_headers" {
  count = var.enable_security_headers ? 1 : 0
  
  name    = "${var.cluster_name}-security-headers"
  runtime = "cloudfront-js-2.0"
  code    = <<-EOF
    function handler(event) {
      var response = event.response;
      var headers = response.headers;
      
      // Add security headers
      headers['strict-transport-security'] = { value: 'max-age=31536000; includeSubDomains' };
      headers['x-content-type-options'] = { value: 'nosniff' };
      headers['x-frame-options'] = { value: 'DENY' };
      headers['x-xss-protection'] = { value: '1; mode=block' };
      headers['referrer-policy'] = { value: 'strict-origin-when-cross-origin' };
      headers['permissions-policy'] = { value: 'camera=(), microphone=(), geolocation=()' };
      
      // Content Security Policy
      headers['content-security-policy'] = { 
        value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-src 'self'; object-src 'none'; media-src 'self';"
      };
      
      return response;
    }
  EOF
}