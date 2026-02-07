variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "api_gateway_url" {
  description = "API Gateway URL"
  type        = string
}

variable "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  type        = string
}

variable "enable_logging" {
  description = "Enable CloudFront logging"
  type        = bool
  default     = true
}

variable "log_bucket_name" {
  description = "S3 bucket name for logs"
  type        = string
}

variable "ssl_certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
  default     = null
}

variable "custom_domain" {
  description = "Custom domain name"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
