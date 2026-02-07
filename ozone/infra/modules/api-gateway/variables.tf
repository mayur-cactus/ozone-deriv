variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Lambda invoke ARN"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "enable_cors" {
  description = "Enable CORS"
  type        = bool
  default     = true
}

variable "cors_allow_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "enable_access_logs" {
  description = "Enable access logs"
  type        = bool
  default     = true
}

variable "throttle_burst_limit" {
  description = "Throttle burst limit"
  type        = number
  default     = 500
}

variable "throttle_rate_limit" {
  description = "Throttle rate limit"
  type        = number
  default     = 100
}

variable "custom_domain" {
  description = "Custom domain name"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
