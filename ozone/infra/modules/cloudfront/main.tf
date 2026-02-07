# CloudFront Module

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "AI WAF CloudFront Distribution"
  default_root_object = "index.html"
  web_acl_id          = var.waf_web_acl_id

  origin {
    domain_name = replace(var.api_gateway_url, "/^https?://([^/]*).*/", "$1")
    origin_id   = "api-gateway"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-CloudFront-Secret"
      value = random_password.cloudfront_secret.result
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "api-gateway"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "X-Request-Id"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  # Cache behavior for static content (if using S3 origin later)
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "api-gateway"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.ssl_certificate_arn == null
    acm_certificate_arn            = var.ssl_certificate_arn
    ssl_support_method             = var.ssl_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  dynamic "aliases" {
    for_each = var.custom_domain != null ? [var.custom_domain] : []
    content {
      aliases = [aliases.value]
    }
  }

  logging_config {
    include_cookies = false
    bucket          = "${var.log_bucket_name}.s3.amazonaws.com"
    prefix          = "cloudfront/"
  }

  tags = var.tags
}

# Random password for CloudFront secret header
resource "random_password" "cloudfront_secret" {
  length  = 32
  special = true
}

# Store CloudFront secret in Secrets Manager
resource "aws_secretsmanager_secret" "cloudfront_secret" {
  name        = "${var.name_prefix}-cloudfront-secret"
  description = "Secret header value for CloudFront to API Gateway"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "cloudfront_secret" {
  secret_id     = aws_secretsmanager_secret.cloudfront_secret.id
  secret_string = random_password.cloudfront_secret.result
}

# CloudWatch Alarms for CloudFront
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  alarm_name          = "${var.name_prefix}-cloudfront-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 60
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Alert on CloudFront 5XX errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
  }

  tags = var.tags
}
