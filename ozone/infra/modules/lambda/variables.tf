variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

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

variable "bedrock_model_id" {
  description = "Bedrock model ID"
  type        = string
}

variable "guardrail_id" {
  description = "Bedrock Guardrail ID"
  type        = string
}

variable "risk_threshold" {
  description = "Risk score threshold for blocking"
  type        = number
  default     = 70
}

variable "log_level" {
  description = "Logging level"
  type        = string
  default     = "INFO"
}

variable "kinesis_stream_arn" {
  description = "Kinesis stream ARN for logging"
  type        = string
}

variable "secrets_manager_arn" {
  description = "Secrets Manager ARN"
  type        = string
  default     = null
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN"
  type        = string
  default     = "*"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
