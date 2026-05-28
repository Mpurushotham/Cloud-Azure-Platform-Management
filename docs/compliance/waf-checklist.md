# Azure Well-Architected Framework Checklist

## Reliability

- [x] Hub VNet deployed across availability zones
- [x] VPN Gateway: active-active, zone-redundant (VpnGw2AZ)
- [x] Azure Firewall Premium: zone-redundant deployment
- [x] Azure Bastion Standard: autoscale enabled
- [x] Log Analytics workspace: geo-redundant storage
- [x] Key Vault: soft-delete (90 days) + purge protection enabled
- [x] Alert rules with action groups and multiple notification channels
- [x] Budgets with forecast alerts to prevent surprise spend
- [x] Runbooks tested and documented in `/docs/runbooks/`
- [ ] Azure Site Recovery configured for IaaS VMs (workload team responsibility)
- [ ] Backup policies defined and tested (workload team responsibility)

## Security

- [x] Azure Firewall Premium with IDPS (Alert and Deny) and TLS inspection
- [x] DDoS Network Protection Plan on Hub VNet
- [x] NSGs on all subnets with default-deny rules
- [x] NSG Flow Logs enabled, sent to Log Analytics
- [x] No public IPs on Corp landing zone (enforced by policy)
- [x] Private endpoints for all PaaS services in Corp LZ
- [x] Azure Bastion for all VM access (no RDP/SSH via internet)
- [x] Entra ID only — no local accounts (enforced by policy)
- [x] PIM eligible assignments for all privileged roles
- [x] Conditional Access: MFA required, legacy auth blocked
- [x] Key Vault: RBAC model, private endpoint, CMK, no access policies
- [x] Defender for Cloud: all plans enabled (Servers P2, Storage, SQL, etc.)
- [x] Microsoft Sentinel: deployed with analytics rules and playbooks
- [x] TLS 1.2+ enforced on Storage, SQL, App Service (Azure Policy)
- [x] CMK enforced on Storage, SQL, Disk (Azure Policy)
- [x] All diagnostic settings → Log Analytics (platform resources)
- [x] Azure Activity Log connected to Sentinel
- [x] No secrets stored in GitHub (OIDC federated identity for CI/CD)
- [ ] Penetration testing schedule established (annual minimum)
- [ ] Security incident runbook rehearsed (tabletop exercise)

## Cost Optimization

- [x] Subscription budgets with 50/75/90/100% thresholds
- [x] Cost anomaly alerts (>20% week-over-week)
- [x] Tagging policy: all 5 required tags enforced
- [x] Tag inheritance from resource group (Environment, CostCenter)
- [x] Sandbox auto-shutdown policy for VMs
- [x] Azure Advisor recommendations review process defined
- [x] Reserved Instance review process for 1-year predictable workloads
- [ ] Savings Plan evaluation for compute (annual review)
- [ ] Idle resource cleanup runbook scheduled (monthly)
- [ ] Orphaned disk/IP/NSG cleanup automation enabled

## Operational Excellence

- [x] All infrastructure as code (Bicep + Terraform) — no manual changes
- [x] GitHub Actions CI/CD: 8 pipelines with security scanning
- [x] PR review required: 2 approvals + CI green
- [x] CODEOWNERS defined for all sensitive paths
- [x] Policy compliance dashboard monitored weekly
- [x] Automated compliance report (PowerShell → Storage)
- [x] Runbooks documented: incident response, cost optimization
- [x] Change tracking solution in Log Analytics
- [x] Platform dashboards: infrastructure, security, cost
- [x] On-call rotation and escalation path documented
- [ ] Game day / chaos engineering schedule defined
- [ ] Post-incident review (PIR) process established

## Performance Efficiency

- [x] Azure Firewall Premium: high-throughput, zone-redundant
- [x] Azure Bastion Standard: autoscale (2–50 instances)
- [x] Private endpoints: eliminate internet routing for PaaS
- [x] DNS Private Resolver: fast internal DNS resolution
- [x] VNet peering: low-latency spoke-to-hub connectivity
- [x] Log Analytics: 90-day interactive retention, 365-day total archive
- [ ] Azure CDN / Front Door for Online workloads (workload team)
- [ ] Auto-scaling policies for compute workloads (workload team)
- [ ] Performance baseline established for critical workloads
