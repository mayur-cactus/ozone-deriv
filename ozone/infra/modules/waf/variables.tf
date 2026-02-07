variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "enable_cloudfront_waf" {
  description = "Enable WAF for CloudFront"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting rules"
  type        = bool
  default     = true
}

variable "rate_limit" {
  description = "Rate limit (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "max_request_size" {
  description = "Maximum request size in KB"
  type        = number
  default     = 128
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
