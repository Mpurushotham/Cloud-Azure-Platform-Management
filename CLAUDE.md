# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

Infrastructure-as-code only — an Azure enterprise platform (management groups, policy, hub-spoke networking, landing zones, security, monitoring, FinOps) built with **Bicep**, **Terraform**, **PowerShell**, and **GitHub Actions**. There is no application code and no unit-test suite; "testing" means template compilation, `terraform validate`/`plan`, security scanning, and `what-if` dry runs.

## Commands

```bash
bash scripts/bash/setup.sh              # install az, bicep, terraform, checkov, pwsh, Az modules

# Validate everything (what CI does)
bash scripts/bash/validate-bicep.sh     # builds every *.bicep, reports pass/fail counts
az bicep build --file <path>.bicep --stdout   # single template
checkov -d . --framework bicep,arm --skip-check CKV_AZURE_1,CKV_AZURE_2
checkov -d terraform/ --framework terraform
pwsh -c "Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning"
python3 -m json.tool governance/policies/custom/<file>.json   # policy/role JSON syntax

# Terraform — always from an environment dir, never terraform/modules
cd terraform/environments/dev
terraform init -reconfigure && terraform validate
terraform plan -var="subscription_id=<sub-id>"
```

Deployment happens through CI (see below). Manual `az deployment ...` invocations for bootstrap are documented in `README.md` "Quick Start".

## Bicep deployment scopes

The `targetScope` at the top of each `main.bicep` determines the CLI verb — getting this wrong is the most common deployment error:

| `targetScope` | Command | Templates |
|---|---|---|
| `tenant` | `az deployment tenant create --location <loc>` | `governance/management-groups/` |
| `managementGroup` | `az deployment mg create --management-group-id <id> --location <loc>` | `governance/policies/assignments/`, `governance/rbac/assignments/`, `security/zero-trust/pim-config.bicep`, `finops/tagging/` |
| `subscription` | `az deployment sub create --location <loc>` | `networking/hub/`, `networking/spoke/`, all `landing-zones/*`, `security/defender/`, `finops/budgets/` |
| `resourceGroup` | `az deployment group create --resource-group <rg>` | `monitoring/*`, `security/key-vault/`, `security/sentinel/`, `networking/nsg/`, `networking/private-dns/`, `finops/cost-alerts/` |

Subscription-scoped `main.bicep` files own their resource group: they declare `resource rg 'Microsoft.Resources/resourceGroups@...'`, then invoke child templates from `modules/` with `scope: rg`, wiring them together via module `outputs` (e.g. `hubVnet.outputs.firewallSubnetId`). Keep new resources in a `modules/*.bicep` file and compose from `main.bicep`; don't inline resources into `main.bicep`.

Secrets are never parameter values. `@secure()` params (e.g. `vpnSharedKey`) are supplied through a Key Vault `reference` block in `parameters/*.json` — see `networking/hub/parameters/prod.json`.

## Terraform layout

`terraform/environments/{dev,staging,prod}` are three near-identical root modules that each compose `terraform/modules/{monitoring,networking,security}` in that dependency order (monitoring's `workspace_id` feeds the other two; security depends on networking's `management_subnet_id`). **A module change usually requires editing all three environment `main.tf` files** — they are copies, not a shared root with workspaces. Each has its own azurerm backend (`stterraformstate{dev,stg,prod}001`, key `<env>/platform.tfstate`) and uses OIDC (`use_oidc = true`, `ARM_USE_OIDC`). Environment differences are intentional: dev has `enable_ddos_protection = false` and 30-day retention; prod has DDoS on and 90 days.

Note `terraform/modules/monitoring` declares its outputs inline in `main.tf` (no `outputs.tf`), unlike the other two modules.

## Conventions

Resource names follow CAF: `<type-abbrev>-<workload>-<environment>-<region-abbrev>-<instance>`, e.g. `rg-payments-prod-eus-001`, `law-platform-dev-001`, `kv-platform-prod-001`. Region abbreviations are tabulated in `docs/architecture/landing-zone-design.md`.

Every resource group and resource carries these five tags — required by the `require-tags` policy and asserted in deploy workflows: `Environment`, `ManagedBy`, `CostCenter`, `Owner`, `Application`.

Bicep params use `@description()` plus `@allowed([...])` for environment/type enums (`['prod','staging','dev']`, landing-zone types `['corp','online','sandbox']`).

## CI/CD

Workflows are numbered `00`–`07` in `.github/workflows/`. PR gates: `00-pre-checks`, `01-security-scan`, `02-bicep-validate` (path-filtered to `**/*.bicep` and `**/*.json`, excluding workbooks/dashboards), `03-terraform-plan` (path-filtered to `terraform/**`, matrixed over all three environments, posts the plan as a PR comment), `04-governance-check` (path-filtered to `governance/**` and `landing-zones/**`).

Deploys: push to `main` → dev; tag `v*-rc*` → staging; tag `vX.Y.Z` → prod. All authenticate via OIDC federated identity against GitHub environments `dev`/`staging`/`prod` (staging and prod carry approval gates). No stored credentials — never add a workflow step that consumes a client secret.

`04-governance-check` enforces two things beyond JSON syntax: custom RBAC role JSON must contain `Name`, `IsCustom`, `Actions`, `AssignableScopes`, and `governance/management-groups/main.bicep` must keep resource symbols matching `mg_platform|mg_corp|mg_online|mg_sandbox`.

## PR requirements (enforced by `00-pre-checks`)

- Branch name must match `^(feature|fix|hotfix|chore|docs|security|governance|network|finops)/[a-z0-9-]+$`.
- PR title must be semantic with type in: `feat fix chore docs refactor security governance network finops`.
- At least one area label: `governance networking security monitoring finops automation terraform documentation ci-cd`.
- Non-empty PR description; 2 approvals; `.github/CODEOWNERS` adds per-directory reviewers (governance/security/networking changes pull in extra teams).

## Known gaps

`README.md` documents `monitoring/dashboards/`, `automation/functions/`, and `terraform/modules/governance/`, none of which exist yet. `landing-zones/*/parameters.json` files referenced in the README Quick Start are also absent (only `networking/hub/parameters/` and `governance/management-groups/parameters/` exist).
