terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-terraform-state"
    storage_account_name = "stterraformstateprod001"
    container_name       = "tfstate"
    key                  = "prod/platform.tfstate"
    use_oidc             = true
    subscription_id      = "00000000-0000-0000-0000-000000000001"
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
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  use_oidc        = true
  subscription_id = var.subscription_id
}
