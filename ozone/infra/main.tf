terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {
    # Configure in backend-config file or via terraform init -backend-config
    # bucket         = "your-terraform-state-bucket"
    # key            = "ai-waf/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = var.cost_center
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name_prefix         = local.name_prefix
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  enable_nat_gateway  = var.enable_nat_gateway
  enable_vpc_endpoints = true

  tags = local.common_tags
}

# WAF Module
module "waf" {
  source = "./modules/waf"

  name_prefix           = local.name_prefix
  enable_cloudfront_waf = var.enable_cloudfront
  enable_rate_limiting  = true
  rate_limit            = var.waf_rate_limit
  max_request_size      = var.max_request_size

  tags = local.common_tags
}

# Lambda Module
module "lambda" {
  source = "./modules/lambda"

  name_prefix             = local.name_prefix
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  lambda_runtime          = var.lambda_runtime
  lambda_architecture     = var.lambda_architecture
  lambda_memory_size      = var.lambda_memory_size
  lambda_timeout          = var.lambda_timeout
  bedrock_model_id        = var.bedrock_model_id
  guardrail_id            = module.bedrock.guardrail_id
  risk_threshold          = var.risk_threshold
  log_level               = var.log_level
  kinesis_stream_arn      = module.monitoring.kinesis_stream_arn
  secrets_manager_arn     = module.bedrock.secrets_manager_arn

  tags = local.common_tags
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"

  name_prefix          = local.name_prefix
  lambda_invoke_arn    = module.lambda.lambda_invoke_arn
  lambda_function_name = module.lambda.lambda_function_name
  enable_cors          = true
  cors_allow_origins   = var.cors_allow_origins
  enable_access_logs   = true
  throttle_burst_limit = var.api_throttle_burst_limit
  throttle_rate_limit  = var.api_throttle_rate_limit

  tags = local.common_tags
}

# CloudFront Module (Optional)
module "cloudfront" {
  count  = var.enable_cloudfront ? 1 : 0
  source = "./modules/cloudfront"

  name_prefix         = local.name_prefix
  api_gateway_url     = module.api_gateway.api_endpoint
  waf_web_acl_id      = module.waf.cloudfront_web_acl_id
  enable_logging      = true
  log_bucket_name     = module.monitoring.cloudfront_log_bucket
  ssl_certificate_arn = var.ssl_certificate_arn
  custom_domain       = var.custom_domain

  tags = local.common_tags
}

# Bedrock Module
module "bedrock" {
  source = "./modules/bedrock"

  name_prefix                 = local.name_prefix
  guardrail_name              = "${local.name_prefix}-guardrail"
  prompt_attack_filter_strength = var.prompt_attack_filter_strength
  enable_content_filters      = true
  toxicity_threshold          = var.toxicity_threshold
  enable_pii_filter           = var.enable_pii_filter
  blocked_messaging           = var.guardrail_blocked_message

  tags = local.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix              = local.name_prefix
  lambda_function_name     = module.lambda.lambda_function_name
  api_gateway_id           = module.api_gateway.api_id
  cloudfront_distribution_id = var.enable_cloudfront ? module.cloudfront[0].distribution_id : null
  enable_opensearch        = var.enable_opensearch
  opensearch_instance_type = var.opensearch_instance_type
  opensearch_instance_count = var.opensearch_instance_count
  alarm_email              = var.alarm_email
  enable_anomaly_detection = var.enable_anomaly_detection

  tags = local.common_tags
}
