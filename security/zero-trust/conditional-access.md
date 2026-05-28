# Zero Trust — Conditional Access Policies

## Overview

All Conditional Access (CA) policies are configured in Entra ID. They cannot be deployed via ARM/Bicep; they require the Microsoft Graph API or manual configuration. This document defines the required policy set aligned with Zero Trust principles and the MCSB.

**Prerequisites**: Azure AD Premium P2 license for all users subject to these policies.

---

## Policy 1: Require MFA for All Users

| Setting | Value |
|---------|-------|
| Name | ZT-01: Require MFA for All Users |
| Users | All users (exclude break-glass accounts) |
| Cloud Apps | All cloud apps |
| Conditions | Any platform, any location |
| Grant | Require MFA |
| Session | Sign-in frequency: 8 hours |

```powershell
# Deploy via Microsoft Graph PowerShell
$policy = @{
    displayName     = "ZT-01: Require MFA for All Users"
    state           = "enabled"
    conditions      = @{
        users       = @{ includeUsers = @("All"); excludeGroups = @("<break-glass-group-id>") }
        applications = @{ includeApplications = @("All") }
    }
    grantControls   = @{
        operator = "OR"
        builtInControls = @("mfa")
    }
    sessionControls = @{
        signInFrequency = @{ value = 8; type = "hours"; isEnabled = $true }
    }
}
New-MgIdentityConditionalAccessPolicy -BodyParameter $policy
```

---

## Policy 2: Block Legacy Authentication

| Setting | Value |
|---------|-------|
| Name | ZT-02: Block Legacy Authentication Protocols |
| Users | All users |
| Cloud Apps | All cloud apps |
| Conditions | Client apps: Exchange ActiveSync, Other clients (IMAP, POP3, SMTP) |
| Grant | Block access |

**Rationale**: Legacy protocols bypass MFA entirely. Defender for Cloud alert: `Possible attempt to bypass MFA by legacy protocol`. Blocking this eliminates the attack vector.

---

## Policy 3: Require Compliant or Hybrid-Joined Device

| Setting | Value |
|---------|-------|
| Name | ZT-03: Require Compliant Device for Corporate Apps |
| Users | All users (exclude service accounts, Intune enrollment) |
| Cloud Apps | Office 365, Azure Management |
| Conditions | Any platform |
| Grant | Require: Compliant device OR Hybrid AD joined |

---

## Policy 4: Privileged Role Activation — Require MFA + Compliant Device

| Setting | Value |
|---------|-------|
| Name | ZT-04: Require MFA + Compliant Device for Privileged Roles |
| Users | Directory roles: Global Admin, Privileged Role Admin, Security Admin, User Access Admin |
| Cloud Apps | Microsoft Azure Management, Azure AD Admin portal |
| Grant | Require MFA AND require compliant device |
| Session | Sign-in frequency: 1 hour; persistent browser: Never |

---

## Policy 5: Block Access from Untrusted Locations

| Setting | Value |
|---------|-------|
| Name | ZT-05: Block Access from High-Risk Countries |
| Users | All users (exclude emergency access) |
| Cloud Apps | All cloud apps |
| Conditions | Locations: Exclude named "Trusted Corporate Networks"; Include "All locations" |
| Grant | Block access from: KP, RU, CN, IR (adjust per organization risk tolerance) |

---

## Policy 6: Require MFA at High Sign-in Risk

| Setting | Value |
|---------|-------|
| Name | ZT-06: Require MFA for High-Risk Sign-ins |
| Users | All users |
| Cloud Apps | All cloud apps |
| Conditions | Sign-in risk: High |
| Grant | Require MFA |
| Note | Requires Entra ID P2 (Identity Protection) |

---

## Policy 7: Block High-Risk Users

| Setting | Value |
|---------|-------|
| Name | ZT-07: Block High-Risk Users Until Remediated |
| Users | All users |
| Cloud Apps | All cloud apps |
| Conditions | User risk: High |
| Grant | Block access |
| Note | User must change password and confirm MFA before access restored |

---

## Break-Glass Accounts

Maintain 2 break-glass (emergency access) accounts:
- Excluded from ALL Conditional Access policies
- No MFA method enrolled (use strong random password + hardware token)
- Password stored in physical safe + Azure Key Vault (air-gapped copy)
- Sign-in activity monitored via Sentinel alert rule
- Test access quarterly — log test in audit trail
- Never use for day-to-day operations

---

## Named Locations

Define trusted locations for use in policies:
```powershell
# Trusted Corporate Office IPs
$trustedLocation = @{
    displayName = "Trusted Corporate Networks"
    isTrusted   = $true
    ipRanges    = @(
        @{ cidrAddress = "203.0.113.0/24" }   # HQ
        @{ cidrAddress = "198.51.100.0/24" }  # Remote office
    )
}
New-MgIdentityConditionalAccessNamedLocation -BodyParameter $trustedLocation
```
