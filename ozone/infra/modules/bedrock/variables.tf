variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "guardrail_name" {
  description = "Name of the Bedrock Guardrail"
  type        = string
}

variable "prompt_attack_filter_strength" {
  description = "Prompt attack filter strength (LOW, MEDIUM, HIGH)"
  type        = string
  default     = "HIGH"
}

variable "enable_content_filters" {
  description = "Enable content filters"
  type        = bool
  default     = true
}

variable "toxicity_threshold" {
  description = "Toxicity threshold"
  type        = number
  default     = 0.5
}

variable "enable_pii_filter" {
  description = "Enable PII filtering"
  type        = bool
  default     = true
}

variable "blocked_messaging" {
  description = "Message to return when content is blocked"
  type        = string
  default     = "I apologize, but I cannot process this request as it violates our security policies."
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
