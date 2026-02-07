# Lambda Module for AI WAF

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for AI WAF Lambda function"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for AWS API calls"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound (can be restricted further)"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lambda-sg"
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-lambda-role"

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

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda" {
  name = "${var.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ApplyGuardrail"
        ]
        Resource = "arn:aws:bedrock:*:*:guardrail/*"
      },
      {
        Effect = "Allow"
        Action = [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Subscribe"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.secrets_manager_arn != null ? var.secrets_manager_arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = var.kinesis_stream_arn
      },
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = "*",
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name_prefix}-ai-waf"
  retention_in_days = 30

  tags = var.tags
}

# Build Lambda deployment package
resource "null_resource" "build_lambda" {
  triggers = {
    # Rebuild if main.py or requirements.txt changes
    main_py_hash         = filemd5("${path.module}/../../../src/lambda/ai-waf-gateway/main.py")
    requirements_hash    = filemd5("${path.module}/../../../src/lambda/ai-waf-gateway/requirements.txt")
    build_script_hash    = filemd5("${path.module}/../../../src/lambda/ai-waf-gateway/build.sh")
  }

  provisioner "local-exec" {
    command     = "chmod +x build.sh && ./build.sh"
    working_dir = "${path.module}/../../../src/lambda/ai-waf-gateway"
  }
}

# Data source to get the deployment zip hash after build
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/lambda/ai-waf-gateway"
  output_path = "${path.module}/../../../src/lambda/ai-waf-gateway/deployment-tf.zip"
  excludes    = ["deployment.zip", "build", "__pycache__", "*.pyc", ".DS_Store"]
  
  depends_on = [null_resource.build_lambda]
}

# Lambda Function
resource "aws_lambda_function" "ai_waf" {
  
  function_name    = "${var.name_prefix}-ai-waf"
  role             = aws_iam_role.lambda.arn
  handler          = "main.lambda_handler"
  runtime          = var.lambda_runtime
  architectures    = [var.lambda_architecture]
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      BEDROCK_MODEL_ID   = var.bedrock_model_id
      GUARDRAIL_ID       = var.guardrail_id
      RISK_THRESHOLD     = tostring(var.risk_threshold)
      LOG_LEVEL          = var.log_level
      KINESIS_STREAM_ARN = var.kinesis_stream_arn
      ENVIRONMENT        = var.tags["Environment"]
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda,
    data.archive_file.lambda_zip
  ]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This alarm monitors Lambda errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.ai_waf.function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.name_prefix}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Average"
  threshold           = var.lambda_timeout * 1000 * 0.8 # 80% of timeout
  alarm_description   = "This alarm monitors Lambda duration"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.ai_waf.function_name
  }

  tags = var.tags
}
