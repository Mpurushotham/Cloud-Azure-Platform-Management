# Cloud-Azure-Platform-Management

Production-grade, enterprise Azure Cloud Platform implementing end-to-end governance, security, networking, and DevSecOps capabilities using **GitHub Actions**, **Bicep**, and **Terraform**, aligned with the **Microsoft Cloud Adoption Framework (CAF)**, **Azure Well-Architected Framework (WAF)**, and **Zero Trust** security model.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    Azure Management Group Hierarchy (CAF)                    │
│                                                                              │
│  Root Management Group                                                       │
│  └── Contoso (Tenant Root)                                                   │
│      ├── Platform MG                                                         │
│      │   ├── Identity Subscription        (Entra ID, PIM, AAD DS)           │
│      │   ├── Management Subscription      (Log Analytics, Automation, Backup)│
│      │   └── Connectivity Subscription    (Hub VNet, Firewall, VPN, DNS)    │
│      ├── Landing Zones MG                                                    │
│      │   ├── Corp MG                                                         │
│      │   │   └── Corp Subscriptions       (Private, hub-connected workloads) │
│      │   └── Online MG                                                       │
│      │       └── Online Subscriptions     (Internet-facing, WAF-protected)   │
│      ├── Sandbox MG                                                          │
│      │   └── Sandbox Subscriptions        (Isolated, dev/test, auto-expire)  │
│      └── Decommissioned MG                                                   │
│          └── Retired Subscriptions        (Quarantined, read-only)           │
│                                                                              │
│  SCPs (Azure Policy) enforced at each MG level                               │
│  RBAC: Platform Engineer · Network Operator · Security Reader · LZ Owner     │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                     Hub-Spoke Network Topology (CAF)                         │
│                                                                              │
│  ┌────────────────────── Connectivity Subscription ─────────────────────┐   │
│  │                                                                       │   │
│  │  Hub VNet: 10.0.0.0/16                                                │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │   │
│  │  │  AzureFirewallSubnet  10.0.0.0/26   [Firewall Premium + IDPS]  │  │   │
│  │  │  GatewaySubnet        10.0.1.0/27   [VPN GW Active-Active]     │  │   │
│  │  │  AzureBastionSubnet   10.0.2.0/26   [Bastion Standard]         │  │   │
│  │  │  ManagementSubnet     10.0.3.0/24   [JumpBox, Automation]      │  │   │
│  │  └─────────────────────────────────────────────────────────────────┘  │   │
│  │                                │ VNet Peering                          │   │
│  └────────────────────────────────┼──────────────────────────────────────┘   │
│                                   │                                          │
│          ┌────────────────────────┼───────────────────────────┐              │
│          │                        │                           │              │
│  ┌───────▼──────────┐   ┌────────▼─────────┐   ┌───────────▼──────────┐    │
│  │  Corp Spoke VNet │   │ Online Spoke VNet │   │  Sandbox VNet        │    │
│  │  10.10.0.0/16    │   │  10.20.0.0/16    │   │  172.16.0.0/16       │    │
│  │                  │   │                  │   │  (No hub peering)    │    │
│  │  PrivateOnly     │   │  AppGW WAF v2    │   │  Isolated            │    │
│  │  Private Endpoints│  │  NSG 80/443 in   │   │  Budget-capped       │    │
│  │  No Public IPs   │   │  Private Svc     │   │  Auto-shutdown       │    │
│  └──────────────────┘   └──────────────────┘   └──────────────────────┘    │
│                                                                              │
│  Private DNS Zones (linked to hub):                                          │
│  privatelink.blob.core.windows.net · privatelink.vaultcore.azure.net        │
│  privatelink.database.windows.net · privatelink.azurecr.io                  │
│  privatelink.aks.azure.com · privatelink.servicebus.windows.net             │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                         Security Architecture (Zero Trust)                   │
│                                                                              │
│  Identity Layer:    Entra ID → Conditional Access → PIM (JIT) → MFA         │
│  Network Layer:     Azure Firewall Premium → IDPS → TLS Inspection          │
│  Data Layer:        Key Vault (RBAC) → CMK → Private Endpoints → TLS 1.2+  │
│  Application Layer: Defender for Cloud (CSPM) → DCSPM → Regulatory Compliance│
│  SIEM/SOAR:         Microsoft Sentinel → Analytics Rules → Playbooks        │
│  Posture:           Secure Score → Recommendations → Auto-Remediation       │
└──────────────────────────────────────────────────────────────────────────────┘

CI/CD Pipeline (GitHub Actions — numbered 00–07):
  00-pre-checks → 01-security-scan → 02-bicep-validate → 03-terraform-plan
  → 04-governance-check → 05-deploy-dev → 06-deploy-staging → 07-deploy-prod

Security Layers:
  Azure Policy → RBAC → NSGs → Azure Firewall → Private Endpoints → Key Vault
  → Defender for Cloud → Microsoft Sentinel → Activity Logs → Diagnostic Settings
```

## Repository Structure

```
Cloud-Azure-Platform-Management/
├── .github/workflows/     # 8 numbered GitHub Actions CI/CD pipelines (OIDC — no stored secrets)
├── docs/
│   ├── architecture/      # Hub-spoke topology, landing zone design diagrams
│   ├── runbooks/          # Incident response, cost optimization procedures
│   └── compliance/        # CAF alignment matrix, WAF pillar checklists
├── governance/
│   ├── management-groups/ # Bicep: full MG hierarchy (CAF-aligned)
│   ├── rbac/              # Custom role JSON definitions + Bicep assignments
│   └── policies/          # Custom policy JSON, initiatives, Bicep assignments
├── networking/
│   ├── hub/               # Bicep: Hub VNet, Azure Firewall Premium, VPN GW, Bastion, DDoS
│   ├── spoke/             # Bicep: Parameterized spoke template + peering
│   ├── private-dns/       # Bicep: Private DNS zones for all PaaS services
│   └── nsg/               # Bicep: NSG rule sets (hub tiers + spoke tiers)
├── landing-zones/
│   ├── corp/              # Bicep: Corp LZ (private connectivity, no internet)
│   ├── online/            # Bicep: Online LZ (internet-facing, WAF-fronted)
│   └── sandbox/           # Bicep: Sandbox LZ (isolated, budget-limited, auto-expire)
├── security/
│   ├── defender/          # Bicep: Defender for Cloud — all plans + CSPM + auto-provisioning
│   ├── sentinel/          # Bicep: Microsoft Sentinel workspace, connectors, analytics rules
│   ├── key-vault/         # Bicep: Key Vault (RBAC, private endpoint, CMK, soft-delete)
│   └── zero-trust/        # Bicep + docs: PIM, Conditional Access, MFA policies
├── monitoring/
│   ├── log-analytics/     # Bicep: Log Analytics workspace, solutions, diagnostic settings
│   ├── dashboards/        # JSON: Azure Portal dashboards (platform, security, cost)
│   ├── alerts/            # Bicep: Metric + log alert rules, action groups
│   └── workbooks/         # JSON: Azure Monitor workbooks (infrastructure, security, network)
├── finops/
│   ├── budgets/           # Bicep: Subscription budgets with multi-threshold alerts
│   ├── cost-alerts/       # Bicep: Cost anomaly detection, Advisor automation
│   └── tagging/           # Bicep + JSON: Tag governance policy, inheritance, naming
├── automation/
│   ├── runbooks/          # PowerShell: VM schedule, stale cleanup, compliance report
│   └── functions/         # Azure Functions: event-driven cost/security automation
├── terraform/
│   ├── modules/           # 4 reusable TF modules: networking, governance, security, monitoring
│   └── environments/      # Per-environment root modules: dev, staging, prod (remote state)
├── scripts/
│   ├── powershell/        # Bootstrap: governance setup, landing zone vending, compliance check
│   └── bash/              # Bootstrap: tool install, Bicep validation, resource cleanup
└── README.md
```

## Quick Start

### Prerequisites

```bash
# Install toolchain
az --version          # Azure CLI >= 2.55
bicep --version       # Bicep CLI >= 0.24 (installed via az bicep install)
terraform --version   # Terraform >= 1.7
checkov --version     # Checkov >= 3.2
pwsh --version        # PowerShell >= 7.4

# Or use the bootstrap script:
bash scripts/bash/setup.sh
```

### 1. Bootstrap Governance

```bash
# Authenticate with an account that has Owner on the root management group
az login
az account set --subscription <management-subscription-id>

# Deploy management group hierarchy
az deployment tenant create \
  --location eastus \
  --template-file governance/management-groups/main.bicep \
  --parameters governance/management-groups/parameters/prod.json

# Deploy custom RBAC roles (at root MG scope)
az deployment mg create \
  --management-group-id <root-mg-id> \
  --location eastus \
  --template-file governance/rbac/assignments/main.bicep
```

### 2. Deploy Connectivity Hub

```bash
# Deploy hub networking (Connectivity subscription)
az deployment sub create \
  --location eastus \
  --template-file networking/hub/main.bicep \
  --parameters networking/hub/parameters/prod.json
```

### 3. Onboard a Landing Zone

```bash
# Corp landing zone (private workloads)
az deployment sub create \
  --location eastus \
  --template-file landing-zones/corp/main.bicep \
  --parameters @landing-zones/corp/parameters.json

# Or use the PowerShell vending script:
pwsh scripts/powershell/Deploy-LandingZone.ps1 -LandingZoneType Corp -SubscriptionId <id>
```

### 4. Enable Security Controls

```bash
# Enable all Defender for Cloud plans
az deployment sub create \
  --location eastus \
  --template-file security/defender/main.bicep

# Deploy Microsoft Sentinel
az deployment group create \
  --resource-group rg-sentinel-prod \
  --template-file security/sentinel/main.bicep
```

## CI/CD Pipeline

| # | Workflow | Trigger | Description |
|---|----------|---------|-------------|
| 00 | `00-pre-checks.yml` | PR opened | Validate PR title, branch naming, labels |
| 01 | `01-security-scan.yml` | PR | Checkov, tfsec, PSScriptAnalyzer, MSDO |
| 02 | `02-bicep-validate.yml` | PR | Bicep build + deployment what-if |
| 03 | `03-terraform-plan.yml` | PR | TF init + plan for all environments |
| 04 | `04-governance-check.yml` | PR | Policy compliance dry-run |
| 05 | `05-deploy-dev.yml` | Push to `main` | Auto-deploy to dev (OIDC) |
| 06 | `06-deploy-staging.yml` | Tag `v*-rc*` | Deploy to staging + approval gate |
| 07 | `07-deploy-prod.yml` | Tag `v*` | Deploy to prod + required reviewers |

All pipelines authenticate via **OIDC Federated Identity** — zero stored credentials.

## Governance & Compliance

| Framework | Alignment |
|-----------|-----------|
| Microsoft CAF | Landing zones, management group hierarchy, subscription vending |
| Azure WAF | Reliability, Security, Cost Optimization, Operational Excellence, Performance |
| MCSB v3 | Network Security, Identity, Privileged Access, Data Protection, Logging |
| Zero Trust | Verify explicitly, Least privilege, Assume breach |
| CIS Azure Benchmark | Integrated via Defender for Cloud regulatory compliance dashboard |
| NIST SP 800-53 | Mapped via Microsoft Sentinel and Defender for Cloud |

## MCSB Security Controls

| Control Domain | Implementation |
|---------------|----------------|
| NS-1 Network Segmentation | Hub-spoke VNets, NSGs with deny-all default |
| NS-2 Private Connectivity | Private endpoints for all PaaS (Storage, KV, SQL, ACR, AKS) |
| NS-3 DDoS Protection | DDoS Network Protection Plan on hub VNet |
| NS-6 Web Application Firewall | Azure App Gateway WAF v2 on Online landing zone |
| IM-1 Centralized Identity | Entra ID — no local accounts, no shared accounts |
| IM-3 Application Identities | Managed Identities (no service principal secrets) |
| PA-1 Privileged Access | PIM eligible assignments, JIT activation, approval required |
| PA-2 Non-standing Privileges | No permanent Owner/Contributor on production |
| DP-1 Encryption at Rest | Azure Policy: CMK on Storage, SQL, Disk |
| DP-3 Sensitive Data Encryption | Key Vault (RBAC), TLS 1.2+ enforced via policy |
| LT-1 Security Logging | Diagnostic settings on all resources → Log Analytics |
| LT-3 Security Audit | Azure Activity Log, Microsoft Sentinel |
| IR-1 Incident Response | Sentinel playbooks, action groups, on-call routing |
| PV-1 Vulnerability Assessment | Defender for Cloud CSPM, DCSPM, agentless scanning |

## FinOps

| Mechanism | Configuration |
|-----------|--------------|
| Subscription Budgets | Dev $500 · Staging $2,000 · Prod $10,000/month |
| Alert Thresholds | 50% · 75% · 90% · 100% (forecast) |
| Cost Anomaly Alerts | >20% week-over-week increase |
| Azure Advisor | Auto-rightsizing recommendations via Logic App |
| Reserved Instances | 1-year commitment for predictable workloads (Compute, SQL) |
| Savings Plans | Azure Compute Savings Plan for variable workloads |
| Tagging | Environment · CostCenter · Owner · Application · ManagedBy |

## Contributing

1. Branch from `main`: `feature/<description>` or `fix/<description>`
2. All PRs require 2 approvals + passing CI (workflows 00–04)
3. Production changes require platform team lead sign-off
4. Follow naming conventions in `docs/architecture/landing-zone-design.md`

## License

MIT — See [LICENSE](LICENSE)
