variable "location" {
  description = "Azure region for the registry"
  type        = string
}

variable "location_abbrev" {
  description = "Short region code used in resource names (e.g. eus)"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace to send registry diagnostics to"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
}
