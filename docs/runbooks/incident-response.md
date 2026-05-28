# Incident Response Runbook

## Severity Classification

| Severity | Criteria | Response Time | Escalation |
|----------|----------|---------------|-----------|
| SEV1 | Production outage, data breach, ransomware | 15 minutes | Platform Lead + CISO |
| SEV2 | Degraded production service, active threat | 30 minutes | Platform Lead |
| SEV3 | Non-critical service impact, policy violation | 2 hours | Team Lead |
| SEV4 | Informational alert, advisory | Next business day | Owner |

## Common Incident Scenarios

### Scenario 1: Suspected Account Compromise

**Indicators**: Microsoft Sentinel — impossible travel alert, anomalous sign-in alert

**Response Steps**:
1. **Contain**: Immediately revoke all active sessions for the user account
   ```powershell
   # Revoke all refresh tokens for user
   az ad user revoke-sign-in-sessions --id <upn>
   ```
2. **Contain**: Disable the user account if breach confirmed
   ```powershell
   az ad user update --id <upn> --account-enabled false
   ```
3. **Investigate**: Pull sign-in logs from Entra ID (last 30 days)
4. **Investigate**: Check Azure Activity Log for any resource changes by the account
5. **Investigate**: Review PIM activation history for the account
6. **Eradicate**: Reset credentials, re-enable MFA, review and remove unauthorized access grants
7. **Recover**: Re-enable account after credential reset and sign-in verification
8. **Post-Incident**: Document in incident tracker, update Conditional Access if needed

---

### Scenario 2: Azure Firewall Threat Intel Alert

**Indicators**: Monitoring alert — `AzureDiagnostics | where Category == "AzureFirewallThreatIntelLog"`

**Response Steps**:
1. **Investigate**: Query firewall logs in Log Analytics
   ```kusto
   AzureDiagnostics
   | where Category == "AzureFirewallThreatIntelLog"
   | project TimeGenerated, msg_s, Protocol, SourceIp, DestinationIp, Action_s
   | order by TimeGenerated desc
   | take 100
   ```
2. **Assess**: Identify source IP — internal VM or external attacker?
3. **Contain**: If internal VM is compromised — isolate by applying deny-all NSG
   ```bash
   az network nsg rule create --nsg-name <nsg> -g <rg> -n IsolateVM \
     --priority 100 --direction Inbound --access Deny \
     --source-address-prefixes '*' --destination-address-prefixes <vm-private-ip>
   ```
4. **Preserve**: Take VM disk snapshot before any remediation
5. **Investigate**: Run Defender for Cloud — endpoint threat detection on the VM
6. **Eradicate**: Rebuild VM from known-good image if malware confirmed
7. **Post-Incident**: Review firewall rules, update threat intel feeds

---

### Scenario 3: Policy Compliance Violation

**Indicators**: Azure Policy compliance dashboard — non-compliant resource created

**Response Steps**:
1. **Identify**: Query policy compliance state
   ```bash
   az policy state list --filter "complianceState eq 'NonCompliant'" \
     --query "[].{Resource:resourceId, Policy:policyDefinitionName}"
   ```
2. **Assess**: Was this created via CI/CD (controlled) or manual (unauthorized)?
3. **Contain**: If unauthorized change — escalate to asset owner
4. **Remediate**: Trigger policy remediation task
   ```bash
   az policy remediation create \
     --name remediation-$(date +%Y%m%d) \
     --policy-assignment <assignment-id> \
     --resource-discovery-mode ExistingNonCompliant
   ```
5. **Prevent**: Review and tighten policy effect (Audit → Deny if appropriate)

---

### Scenario 4: Unexpected Cost Spike

**Indicators**: Budget alert — 90% threshold reached, cost anomaly alert

**Response Steps**:
1. **Investigate**: Open Azure Cost Management + Billing
2. **Query**: Identify top spending resources in the current billing period
   ```bash
   az consumption usage list --start-date $(date -d '-7 days' +%Y-%m-%d) \
     --end-date $(date +%Y-%m-%d) --top 20 \
     --query "sort_by(@, &pretaxCost)[-20:].{Resource:instanceName, Cost:pretaxCost}"
   ```
3. **Identify**: Look for unexpected VMs, large storage transactions, egress charges
4. **Action**: Stop/delete unauthorized resources immediately
5. **Investigate**: Determine if this was authorized (missed budget estimate) or unauthorized (rogue deployment)
6. **Prevent**: Update budget thresholds, review pipeline guardrails

---

## Contact List

| Role | Contact | Escalation Path |
|------|---------|----------------|
| Platform Lead | platform-lead@contoso.com | SEV1, SEV2 |
| Security Lead / CISO | security-lead@contoso.com | SEV1 (data breach, ransomware) |
| Network Team | network-team@contoso.com | Network incidents |
| Identity Team | identity-team@contoso.com | Account compromise, MFA issues |
| FinOps Lead | finops@contoso.com | Budget overrun, cost anomalies |
| Microsoft Support | Azure Support ticket (Premier) | Azure platform issues |

## Post-Incident Review Template

```markdown
## Incident Summary
- **Date/Time**: 
- **Duration**: 
- **Severity**: 
- **Services Affected**: 
- **Impact**: 

## Timeline
| Time | Event |
|------|-------|
| HH:MM | Alert triggered |
| HH:MM | On-call paged |
| HH:MM | Investigation began |
| HH:MM | Root cause identified |
| HH:MM | Mitigation applied |
| HH:MM | Service restored |

## Root Cause

## Contributing Factors

## Immediate Actions Taken

## Follow-up Actions (with owners and due dates)
| Action | Owner | Due Date |
|--------|-------|---------|
| | | |

## Lessons Learned
```
