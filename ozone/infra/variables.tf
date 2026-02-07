variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ai-waf"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets"
  type        = bool
  default     = true
}

# WAF Variables
variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "max_request_size" {
  description = "Maximum request size in KB"
  type        = number
  default     = 128
}

# Lambda Variables
variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "lambda_architecture" {
  description = "Lambda architecture (x86_64 or arm64)"
  type        = string
  default     = "arm64"
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 1024
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Logging level (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
}

# Bedrock Variables
variable "bedrock_model_id" {
  description = "Bedrock model ID for classification"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "prompt_attack_filter_strength" {
  description = "Bedrock Guardrail prompt attack filter strength (LOW, MEDIUM, HIGH)"
  type        = string
  default     = "HIGH"
  validation {
    condition     = contains(["LOW", "MEDIUM", "HIGH"], var.prompt_attack_filter_strength)
    error_message = "Strength must be LOW, MEDIUM, or HIGH."
  }
}

variable "toxicity_threshold" {
  description = "Toxicity filter threshold (0.0-1.0)"
  type        = number
  default     = 0.5
}

variable "enable_pii_filter" {
  description = "Enable PII detection and filtering"
  type        = bool
  default     = true
}

variable "guardrail_blocked_message" {
  description = "Message returned when Guardrail blocks content"
  type        = string
  default     = "I apologize, but I cannot process this request as it violates our security policies."
}

variable "risk_threshold" {
  description = "Risk score threshold for blocking (0-100)"
  type        = number
  default     = 70
  validation {
    condition     = var.risk_threshold >= 0 && var.risk_threshold <= 100
    error_message = "Risk threshold must be between 0 and 100."
  }
}

# API Gateway Variables
variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 500
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "cors_allow_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

# CloudFront Variables
variable "enable_cloudfront" {
  description = "Enable CloudFront distribution"
  type        = bool
  default     = true
}

variable "ssl_certificate_arn" {
  description = "ACM certificate ARN for custom domain (must be in us-east-1)"
  type        = string
  default     = null
}

variable "custom_domain" {
  description = "Custom domain name for CloudFront"
  type        = string
  default     = null
}

# Monitoring Variables
variable "enable_opensearch" {
  description = "Enable OpenSearch for log analytics"
  type        = bool
  default     = false # Set to true for production
}

variable "opensearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 1
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "enable_anomaly_detection" {
  description = "Enable CloudWatch anomaly detection"
  type        = bool
  default     = true
}
