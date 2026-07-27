terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
      // Deliberately NOT the enterprise tree's "~> 3.90" (terraform/environments/*/backend.tf).
      // 3.x is superseded; azurerm_log_analytics_solution and
      // disable_bgp_route_propagation were removed/renamed in 4.x, so inheriting
      // that pin would teach an obsolete dialect.
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  // ─── Phase 2: remote state ─────────────────────────────────────────────────
  // Created by lab/scripts/bootstrap-oidc.sh (which resolves the chicken-and-egg:
  // the storage account must exist before `init` can talk to it). The account
  // name is derived from the subscription id, so it is unique per subscription
  // and stable across re-runs — unlike the enterprise tree's hardcoded
  // "stterraformstatedev001", a globally-unique name that is certainly taken.
  //
  // use_azuread_auth is REQUIRED here: the account is created with
  // --allow-shared-key-access false, so there is no access key to fall back on.
  // Authorisation is Entra + "Storage Blob Data Contributor" on the data plane —
  // a control-plane Contributor cannot read these blobs.
  backend "azurerm" {
    resource_group_name  = "rg-lab-tfstate-eus-001"
    storage_account_name = "sttflab357e05621f"
    container_name       = "tfstate"
    key                  = "lab/platform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  // Register providers explicitly via preflight.sh rather than letting the
  // provider do it implicitly — you should know which RPs your platform needs.
  resource_provider_registrations = "none"

  features {}
}

provider "random" {}
