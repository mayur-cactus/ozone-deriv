# Monitoring Module - CloudWatch, Kinesis, OpenSearch

# Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "logs" {
  name        = "${var.name_prefix}-logs"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.logs.arn
    prefix     = "ai-waf-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    buffer_size     = 5
    buffer_interval = 300

    compression_format = "GZIP"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = "S3Delivery"
    }

    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${aws_lambda_function.log_processor.arn}:$LATEST"
        }
      }
    }
  }

  tags = var.tags
}

# S3 Bucket for Logs
resource "aws_s3_bucket" "logs" {
  bucket = "${var.name_prefix}-logs-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# S3 Bucket for CloudFront Logs
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "${var.name_prefix}-cloudfront-logs-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# IAM Role for Firehose
resource "aws_iam_role" "firehose" {
  name = "${var.name_prefix}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "firehose" {
  name = "${var.name_prefix}-firehose-policy"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = aws_lambda_function.log_processor.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.firehose.arn}:*"
      }
    ]
  })
}

# Lambda for Log Processing
resource "aws_lambda_function" "log_processor" {
  filename         = "${path.module}/../../lambda-log-processor.zip"
  function_name    = "${var.name_prefix}-log-processor"
  role             = aws_iam_role.log_processor.arn
  handler          = "processor.lambda_handler"
  source_code_hash = fileexists("${path.module}/../../lambda-log-processor.zip") ? filebase64sha256("${path.module}/../../lambda-log-processor.zip") : ""
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      LOG_LEVEL = var.log_level
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "log_processor" {
  name = "${var.name_prefix}-log-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "log_processor" {
  role       = aws_iam_role.log_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.name_prefix}"
  retention_in_days = 30

  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Lambda Invocations" }],
            [".", "Errors", { stat = "Sum", label = "Lambda Errors" }],
            [".", "Duration", { stat = "Average", label = "Avg Duration (ms)" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Lambda Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", { stat = "Sum", label = "API Requests" }],
            [".", "4XXError", { stat = "Sum", label = "4XX Errors" }],
            [".", "5XXError", { stat = "Sum", label = "5XX Errors" }],
            [".", "Latency", { stat = "Average", label = "Avg Latency (ms)" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "API Gateway Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '/aws/lambda/${var.lambda_function_name}' | fields @timestamp, @message | filter @message like /BLOCKED/ | sort @timestamp desc | limit 20"
          region  = data.aws_region.current.name
          title   = "Recent Blocked Requests"
        }
      }
    ]
  })
}

# Custom CloudWatch Metrics
resource "aws_cloudwatch_log_metric_filter" "prompt_injection" {
  name           = "${var.name_prefix}-prompt-injection"
  log_group_name = "/aws/lambda/${var.lambda_function_name}"
  pattern        = "[time, request_id, level=SECURITY, ...]"

  metric_transformation {
    name      = "PromptInjectionDetected"
    namespace = "AI-WAF"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "blocked_requests" {
  name           = "${var.name_prefix}-blocked-requests"
  log_group_name = "/aws/lambda/${var.lambda_function_name}"
  pattern        = "[time, request_id, level=SECURITY, action=BLOCKED, ...]"

  metric_transformation {
    name      = "BlockedRequests"
    namespace = "AI-WAF"
    value     = "1"
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_block_rate" {
  alarm_name          = "${var.name_prefix}-high-block-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BlockedRequests"
  namespace           = "AI-WAF"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "Alert when block rate is unusually high"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  tags = var.tags
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  count = var.alarm_email != "" ? 1 : 0
  name  = "${var.name_prefix}-alerts"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
