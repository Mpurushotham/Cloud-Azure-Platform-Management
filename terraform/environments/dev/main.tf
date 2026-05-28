locals {
  environment     = "dev"
  location        = "eastus"
  location_abbrev = "eus"
  common_tags = {
    Environment = "dev"
    ManagedBy   = "platform-team"
    CostCenter  = "CC-PLATFORM"
    Owner       = "platform-team@contoso.com"
  }
}

module "monitoring" {
  source = "../../modules/monitoring"

  location            = local.location
  resource_group_name = "rg-platform-monitoring-dev-${local.location_abbrev}-001"
  workspace_name      = "law-platform-dev-001"
  environment         = local.environment
  retention_days      = 30
  alert_email_addresses = var.alert_email_addresses
  common_tags         = local.common_tags
}

module "networking" {
  source = "../../modules/networking"

  location                   = local.location
  location_abbrev             = local.location_abbrev
  environment                 = local.environment
  workload_name               = "platform"
  hub_address_prefix          = var.hub_address_prefix
  enable_ddos_protection      = false
  log_analytics_workspace_id  = module.monitoring.workspace_id
  common_tags                 = local.common_tags
}

module "security" {
  source = "../../modules/security"

  location                   = local.location
  resource_group_name         = "rg-platform-security-dev-${local.location_abbrev}-001"
  key_vault_name              = "kv-platform-dev-001"
  private_endpoint_subnet_id  = module.networking.management_subnet_id
  log_analytics_workspace_id  = module.monitoring.workspace_id
  common_tags                 = local.common_tags

  depends_on = [module.networking]
}
