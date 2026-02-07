# AWS WAF Module for AI WAF System

# CloudFront WAF (Global - us-east-1)
resource "aws_wafv2_web_acl" "cloudfront" {
  count = var.enable_cloudfront_waf ? 1 : 0
  name  = "${var.name_prefix}-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Core Rule Set
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
      metric_name                = "${var.name_prefix}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

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
      metric_name                = "${var.name_prefix}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Bot Control
  rule {
    name     = "AWSManagedRulesBotControlRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesBotControlRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-bot-control"
      sampled_requests_enabled   = true
    }
  }

  # Rate Limiting Rule
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      name     = "RateLimitRule"
      priority = 4

      action {
        block {
          custom_response {
            response_code = 429
            custom_response_body_key = "rate_limit_response"
          }
        }
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-rate-limit"
        sampled_requests_enabled   = true
      }
    }
  }

  # Size Constraint Rule (Limit request body size)
  rule {
    name     = "SizeConstraintRule"
    priority = 5

    action {
      block {
        custom_response {
          response_code = 413
          custom_response_body_key = "size_limit_response"
        }
      }
    }

    statement {
      size_constraint_statement {
        field_to_match {
          body {
            oversize_handling = "CONTINUE"
          }
        }
        comparison_operator = "GT"
        size                = var.max_request_size * 1024 # Convert KB to bytes
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-size-constraint"
      sampled_requests_enabled   = true
    }
  }

  # Custom rule to block suspicious patterns in prompts
  rule {
    name     = "BlockSuspiciousPromptPatterns"
    priority = 6

    action {
      block {
        custom_response {
          response_code = 403
          custom_response_body_key = "suspicious_pattern_response"
        }
      }
    }

    statement {
      or_statement {
        statement {
          byte_match_statement {
            search_string = "ignore all previous instructions"
            field_to_match {
              body {
                oversize_handling = "CONTINUE"
              }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
        statement {
          byte_match_statement {
            search_string = "ignore previous instructions"
            field_to_match {
              body {
                oversize_handling = "CONTINUE"
              }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
        statement {
          byte_match_statement {
            search_string = "reveal your system prompt"
            field_to_match {
              body {
                oversize_handling = "CONTINUE"
              }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-suspicious-patterns"
      sampled_requests_enabled   = true
    }
  }

  # Custom response bodies
  custom_response_body {
    key          = "rate_limit_response"
    content      = jsonencode({
      error = "Rate limit exceeded. Please try again later."
      code  = "RATE_LIMIT_EXCEEDED"
    })
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key          = "size_limit_response"
    content      = jsonencode({
      error = "Request too large. Maximum size is ${var.max_request_size}KB."
      code  = "REQUEST_TOO_LARGE"
    })
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key          = "suspicious_pattern_response"
    content      = jsonencode({
      error = "Request blocked due to suspicious content patterns."
      code  = "SUSPICIOUS_PATTERN_DETECTED"
    })
    content_type = "APPLICATION_JSON"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf-cloudfront"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# Regional WAF (for API Gateway)
resource "aws_wafv2_web_acl" "regional" {
  name  = "${var.name_prefix}-regional-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Similar rules as CloudFront WAF but for regional scope
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
      metric_name                = "${var.name_prefix}-regional-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

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
      metric_name                = "${var.name_prefix}-regional-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for regional
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      name     = "RegionalRateLimitRule"
      priority = 3

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-regional-rate-limit"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf-regional"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# CloudWatch Log Group for WAF Logs
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/waf/${var.name_prefix}"
  retention_in_days = 30

  tags = var.tags
}

# Note: WAF logging configuration requires Kinesis Firehose
# Commented out to avoid error - enable if Kinesis Firehose is set up
# resource "aws_wafv2_web_acl_logging_configuration" "regional" {
#   resource_arn            = aws_wafv2_web_acl.regional.arn
#   log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs.arn]
# 
#   redacted_fields {
#     single_header {
#       name = "authorization"
#     }
#   }
# 
#   redacted_fields {
#     single_header {
#       name = "cookie"
#     }
#   }
# }

