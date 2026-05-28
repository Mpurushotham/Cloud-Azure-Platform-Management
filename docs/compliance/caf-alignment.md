# Microsoft Cloud Adoption Framework (CAF) Alignment

## CAF Ready Phase — Azure Landing Zone Components

| CAF Component | Implementation | Location |
|--------------|----------------|----------|
| Management Group Hierarchy | Bicep — Root → Platform → Landing Zones → Sandbox | `governance/management-groups/` |
| Subscription Vending | PowerShell vending script + Bicep bootstrap | `scripts/powershell/Deploy-LandingZone.ps1` |
| Policy-Driven Governance | Azure Policy initiatives (security + governance baseline) | `governance/policies/` |
| Hub-Spoke Networking | Bicep — Azure Firewall Premium, VPN GW, Bastion | `networking/hub/` |
| Identity & Access | Entra ID + PIM + Conditional Access | `security/zero-trust/` |
| Security Baseline | Defender for Cloud all plans + Sentinel | `security/defender/`, `security/sentinel/` |
| Platform Logging | Log Analytics workspace, diagnostic settings | `monitoring/log-analytics/` |
| Cost Management | Budgets, anomaly alerts, tagging governance | `finops/` |

## CAF Manage Phase — Operational Excellence

| CAF Area | Implementation | Location |
|----------|----------------|----------|
| Azure Monitor baseline | Alert rules — CPU, memory, sign-in failures, firewall | `monitoring/alerts/` |
| Platform dashboards | Azure Portal dashboards (JSON) | `monitoring/dashboards/` |
| Security monitoring | Sentinel analytics rules, workbooks | `security/sentinel/`, `monitoring/workbooks/` |
| Automation | Azure Automation runbooks, Azure Functions | `automation/` |
| Patch management | Update Management via Log Analytics solution | `monitoring/log-analytics/` |
| Incident response | Sentinel playbooks, action groups, runbooks | `docs/runbooks/` |

## CAF Govern Phase — Cloud Governance

| Governance Discipline | Implementation |
|----------------------|----------------|
| Cost Management | Budgets + Advisor + tagging policy + reserved instances guidance |
| Security Baseline | MCSB initiative + Defender for Cloud + Sentinel |
| Resource Consistency | Naming convention policy + tag inheritance + allowed locations |
| Identity Baseline | PIM eligible assignments + Conditional Access + no local accounts |
| Deployment Acceleration | GitHub Actions CI/CD + Bicep + Terraform modules |

## Management Group Policy Matrix

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Policy Assignment Matrix                             │
├─────────────────────────┬──────┬──────────┬──────┬───────┬────────────┤
│ Policy                  │ Root │ Platform │ Corp │ Online│  Sandbox   │
├─────────────────────────┼──────┼──────────┼──────┼───────┼────────────┤
│ Allowed Locations       │  ✓   │    ✓     │  ✓   │   ✓   │     ✓      │
│ Require Tags            │  ✓   │    ✓     │  ✓   │   ✓   │     ✓      │
│ Security Baseline Init. │  ✓   │    ✓     │  ✓   │   ✓   │     ✓      │
│ Governance Baseline     │  ✓   │    ✓     │  ✓   │   ✓   │     ✓      │
│ Enforce TLS 1.2+        │  ✓   │    ✓     │  ✓   │   ✓   │    Audit   │
│ Deny Public IP          │      │          │  ✓   │       │            │
│ Require Private Endpoint│      │          │  ✓   │       │            │
│ Require WAF on AppGW    │      │          │      │   ✓   │            │
│ Auto-shutdown VMs       │      │          │      │       │     ✓      │
│ Budget Alert Required   │      │          │      │       │     ✓      │
│ Audit Public IP         │      │          │      │       │    Audit   │
└─────────────────────────┴──────┴──────────┴──────┴───────┴────────────┘
```

## Azure Well-Architected Framework Pillar Mapping

### Reliability
- Zone-redundant VPN Gateway (active-active)
- Azure Firewall Premium with availability zones
- Log Analytics workspace with 90-day hot retention
- Action groups with multiple notification channels
- Runbook-based auto-remediation

### Security
- Azure Firewall Premium (IDPS, TLS inspection, threat intel)
- Zero Trust: Entra ID + PIM + Conditional Access
- Microsoft Sentinel SIEM/SOAR
- Defender for Cloud (CSPM + workload protection)
- Key Vault (RBAC, private endpoint, CMK, purge protection)
- All policies set to Deny (not just Audit) for critical controls

### Cost Optimization
- Subscription-level budgets with forecast alerts
- Cost anomaly detection with auto-notification
- Advisor rightsizing recommendations via Logic App
- Reserved Instances guidance for 1-year commitments
- Tagging governance for accurate cost allocation
- Sandbox auto-shutdown policy

### Operational Excellence
- GitHub Actions CI/CD with 8 numbered pipelines
- Infrastructure as Code (Bicep + Terraform) — no manual changes
- Drift detection via Azure Policy compliance dashboard
- Automated compliance reports (PowerShell runbook → Storage)
- Runbooks for common operational tasks
- Change tracking via Log Analytics solution

### Performance Efficiency
- Hub-spoke with Azure Firewall for centralized, high-throughput inspection
- Azure Bastion Standard with autoscaling (2–50 instances)
- Private endpoints for PaaS (eliminates internet routing latency)
- DNS Private Resolver for fast internal name resolution
