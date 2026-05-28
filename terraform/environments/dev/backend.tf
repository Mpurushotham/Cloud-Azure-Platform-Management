terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-terraform-state"
    storage_account_name = "stterraformstatedev001"
    container_name       = "tfstate"
    key                  = "dev/platform.tfstate"
    use_oidc             = true
    subscription_id      = "00000000-0000-0000-0000-000000000002"
  }

  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

provider "azurerm" {
  features {}
  use_oidc        = true
  subscription_id = var.subscription_id
}
