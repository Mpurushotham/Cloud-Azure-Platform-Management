terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

# ─── Resource Group ──────────────────────────────────────────────────────────
resource "azurerm_resource_group" "networking" {
  name     = "rg-${var.workload_name}-${var.environment}-${var.location_abbrev}-001"
  location = var.location

  tags = merge(var.common_tags, {
    Application = "hub-connectivity"
  })
}

# ─── DDoS Protection Plan ────────────────────────────────────────────────────
resource "azurerm_network_ddos_protection_plan" "hub" {
  count               = var.enable_ddos_protection ? 1 : 0
  name                = "ddos-${var.workload_name}-${var.environment}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  tags                = var.common_tags
}

# ─── Hub Virtual Network ─────────────────────────────────────────────────────
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.environment}-${var.location_abbrev}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = [var.hub_address_prefix]
  dns_servers         = ["10.0.0.4"] # Azure Firewall as DNS proxy

  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection ? [1] : []
    content {
      id     = azurerm_network_ddos_protection_plan.hub[0].id
      enable = true
    }
  }

  tags = merge(var.common_tags, { Application = "hub-connectivity" })
}

# ─── Hub Subnets ─────────────────────────────────────────────────────────────
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_prefix, 10, 0)]
}

resource "azurerm_subnet" "firewall_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_prefix, 10, 1)]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_prefix, 11, 1)]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_prefix, 10, 2)]
}

resource "azurerm_subnet" "management" {
  name                 = "ManagementSubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_prefix, 8, 3)]
}

# ─── Azure Firewall Public IPs ────────────────────────────────────────────────
resource "azurerm_public_ip" "firewall" {
  name                = "pip-fw-hub-${var.environment}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.common_tags
}

resource "azurerm_public_ip" "firewall_mgmt" {
  name                = "pip-fw-mgmt-${var.environment}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.common_tags
}

# ─── Azure Firewall Policy (Premium) ─────────────────────────────────────────
resource "azurerm_firewall_policy" "hub" {
  name                = "fwpol-hub-${var.environment}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  sku                 = "Premium"
  threat_intelligence_mode = "Deny"

  dns {
    proxy_enabled = true
  }

  intrusion_detection {
    mode = "Deny"
  }

  tags = var.common_tags
}

# ─── Azure Firewall ───────────────────────────────────────────────────────────
resource "azurerm_firewall" "hub" {
  name                = "fw-hub-${var.environment}-${var.location_abbrev}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  zones               = ["1", "2", "3"]
  firewall_policy_id  = azurerm_firewall_policy.hub.id

  ip_configuration {
    name                 = "ipconfig1"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  management_ip_configuration {
    name                 = "mgmt-ipconfig"
    subnet_id            = azurerm_subnet.firewall_mgmt.id
    public_ip_address_id = azurerm_public_ip.firewall_mgmt.id
  }

  tags = merge(var.common_tags, { Application = "hub-connectivity" })
}

# ─── Route Table (force tunnel to Firewall) ────────────────────────────────────
resource "azurerm_route_table" "management" {
  name                          = "rt-management-${var.environment}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.networking.name
  disable_bgp_route_propagation = true

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }

  tags = var.common_tags
}

resource "azurerm_subnet_route_table_association" "management" {
  subnet_id      = azurerm_subnet.management.id
  route_table_id = azurerm_route_table.management.id
}

# ─── Diagnostic Settings ─────────────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-fw-hub-${var.environment}"
  target_resource_id         = azurerm_firewall.hub.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "AzureFirewallApplicationRule" }
  enabled_log { category = "AzureFirewallNetworkRule" }
  enabled_log { category = "AzureFirewallDnsProxy" }
  enabled_log { category = "AzureFirewallThreatIntelLog" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
