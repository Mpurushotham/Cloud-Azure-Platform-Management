variable "location" {
  description = "Azure region for platform resources"
  type        = string
}

variable "location_abbrev" {
  description = "Short region code used in resource names (e.g. eus)"
  type        = string
}

variable "retention_days" {
  description = "Log Analytics retention. 30 is the minimum billable-free period."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 730
    error_message = "retention_days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Hard daily ingestion cap in GB. Keep low on a credit-funded lab."
  type        = number
  default     = 1
}

variable "common_tags" {
  description = "Tags applied to every resource (the five the governance layer will demand)"
  type        = map(string)
}
