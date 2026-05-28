# Landing Zone Design

## Overview

Landing zones provide pre-configured, policy-compliant Azure subscriptions that teams can onboard into immediately. All landing zones follow the **CAF subscription vending** pattern and are governed by Azure Policy at the Management Group level.

## Landing Zone Types

### Corp Landing Zone
For internal, private workloads that require connectivity to on-premises or other Azure resources but **no direct internet access**.

| Property | Value |
|----------|-------|
| Internet Egress | Via Azure Firewall (hub) only |
| Internet Ingress | None — all traffic internal |
| Hub Connectivity | Required (VNet peering to hub) |
| Public IPs | Denied by policy |
| Use Cases | Internal APIs, databases, back-office apps, data platforms |

### Online Landing Zone
For internet-facing workloads that require **public ingress** via Azure Application Gateway WAF v2.

| Property | Value |
|----------|-------|
| Internet Egress | Via Azure Firewall (hub) |
| Internet Ingress | Application Gateway WAF v2 only |
| Hub Connectivity | Required |
| Public IPs | Allowed only on App Gateway (policy-enforced) |
| Use Cases | Customer-facing web apps, public APIs, e-commerce |

### Sandbox Landing Zone
For development, proof-of-concept, and learning workloads with **no production connectivity**.

| Property | Value |
|----------|-------|
| Internet Egress | Direct (no hub connection) |
| Internet Ingress | Discouraged (policy audit) |
| Hub Connectivity | None — fully isolated |
| Public IPs | Allowed (with audit policy) |
| Budget Cap | $200/month — auto-alert at 80% |
| Use Cases | Dev experiments, PoCs, training, sandbox testing |

## Naming Convention

All resources follow this naming convention aligned with CAF:

```
<resource-type-abbrev>-<workload>-<environment>-<region-abbrev>-<instance>

Examples:
  rg-payments-prod-eus-001        Resource Group
  vnet-spoke-corp-prod-eus-001    Virtual Network
  nsg-app-corp-prod-eus-001       Network Security Group
  kv-payments-prod-eus-001        Key Vault
  law-platform-mgmt-eus-001       Log Analytics Workspace
  fw-hub-conn-eus-001             Azure Firewall
  pip-appgw-online-prod-eus-001   Public IP Address
```

### Region Abbreviations
| Azure Region | Abbreviation |
|-------------|-------------|
| East US | eus |
| East US 2 | eus2 |
| West US 2 | wus2 |
| West Europe | weu |
| North Europe | neu |
| UK South | uks |
| Southeast Asia | sea |

### Environment Tags
| Environment | Tag Value | Budget |
|------------|-----------|--------|
| Production | prod | $10,000/mo |
| Staging | staging | $2,000/mo |
| Development | dev | $500/mo |
| Sandbox | sandbox | $200/mo |

## Required Tags (Enforced by Policy)

| Tag Key | Example Value | Description |
|---------|---------------|-------------|
| Environment | prod | Deployment environment |
| CostCenter | CC-12345 | Finance cost center code |
| Owner | team-payments@contoso.com | Team DL or individual email |
| Application | payments-platform | Application or service name |
| ManagedBy | platform-team | Team responsible for the resource |
| DataClassification | internal | public / internal / confidential / restricted |

## Subscription Vending Process

```
1. Team submits landing zone request (ServiceNow / GitHub Issue template)
2. Platform team reviews: use case, budget, connectivity requirement
3. Subscription created from EA enrollment / MCA billing account
4. Subscription moved to appropriate MG (Corp/Online/Sandbox)
5. Policy assignments inherited from MG (no manual step required)
6. Bootstrap Bicep deployed: VNet, Peering, Log Analytics link, Defender plans
7. RBAC: Subscription Owner (Landing Zone Owner role) assigned to requesting team
8. Budget alert created with team email as recipient
9. Team notified — subscription ready within 15 minutes (automated)
```

## Policy Inheritance

```
Root MG Policies (apply everywhere):
  ├── allowed-locations (East US, East US 2, West US 2)
  ├── require-tags (Environment, CostCenter, Owner)
  └── deny-resource-without-managed-identity (VMs)

Platform MG Policies:
  └── (inherits Root + Platform-specific network controls)

Landing Zones MG Policies:
  ├── security-baseline initiative (MCSB-aligned)
  ├── governance-baseline initiative (tagging, naming)
  └── enforce-tls-minimum-version

Corp MG Additional Policies:
  ├── deny-public-ip
  ├── require-private-endpoint-for-paas
  └── deny-unrestricted-nsg-rules

Online MG Additional Policies:
  ├── require-waf-on-application-gateway
  ├── deny-public-ip-except-application-gateway
  └── audit-ddos-protection-enabled

Sandbox MG Additional Policies:
  ├── audit-public-ip (audit only, not deny)
  ├── budget-alert-required
  └── auto-shutdown-required-for-vms
```

## RBAC Model

| Role | Scope | Permissions |
|------|-------|-------------|
| Platform Engineer | Root MG | Full platform operations, no prod delete |
| Network Operator | Connectivity Sub | Network R/W, no compute |
| Security Reader | All MGs | Read security posture, no write |
| Landing Zone Owner | Subscription | Contributor + RBAC write on own subscription |
| Workload Contributor | Resource Group | Contributor on specific RG |
| Cost Reader | Subscription | Read billing + cost data |

All privileged roles use **PIM eligible assignments** — activation requires justification + MFA + optional approval.
