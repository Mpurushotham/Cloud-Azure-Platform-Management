# Hub-Spoke Network Topology

## Overview

This platform implements the Microsoft **CAF Hub-Spoke** network topology. All connectivity flows through a centralized hub VNet hosted in the **Connectivity Subscription** under the **Platform Management Group**. Spoke VNets are deployed per landing zone and peered to the hub.

## Address Space Allocation

| Network | CIDR | Owner | Notes |
|---------|------|-------|-------|
| Hub VNet | 10.0.0.0/16 | Platform Team | Connectivity subscription |
| Corp Spoke (prod) | 10.10.0.0/16 | Corp LZ Owner | Hub-connected |
| Corp Spoke (staging) | 10.11.0.0/16 | Corp LZ Owner | Hub-connected |
| Corp Spoke (dev) | 10.12.0.0/16 | Corp LZ Owner | Hub-connected |
| Online Spoke (prod) | 10.20.0.0/16 | Online LZ Owner | Hub-connected |
| Online Spoke (staging) | 10.21.0.0/16 | Online LZ Owner | Hub-connected |
| Sandbox VNet | 172.16.0.0/16 | Sandbox Owner | **Not** hub-connected |
| On-premises (via VPN) | 192.168.0.0/16 | Network Team | Site-to-site VPN |

## Hub Subnet Design

```
Hub VNet: 10.0.0.0/16
├── AzureFirewallSubnet      10.0.0.0/26    /26 required by Azure Firewall
├── AzureFirewallManagementSubnet 10.0.0.64/26  Required for forced tunneling
├── GatewaySubnet            10.0.1.0/27    /27 minimum for VPN GW
├── AzureBastionSubnet       10.0.2.0/26    /26 minimum for Bastion
├── ManagementSubnet         10.0.3.0/24    Jumpboxes, Automation workers
└── DNSResolverSubnet        10.0.4.0/28    Azure DNS Private Resolver
```

## Spoke Subnet Design (per Landing Zone)

```
Corp Spoke VNet: 10.10.0.0/16
├── AppSubnet                10.10.1.0/24   Application VMs / AKS nodes
├── DataSubnet               10.10.2.0/24   Azure SQL, PostgreSQL, private endpoints
├── IntegrationSubnet        10.10.3.0/24   APIM, Service Bus, Logic Apps
└── PrivateEndpointSubnet    10.10.4.0/24   All PaaS private endpoints
```

## Traffic Flow

### Inbound (On-Premises → Azure)
```
On-Premises → VPN Gateway (Hub) → Azure Firewall → Route Table → Spoke Workload
```

### Inbound (Internet → Online Workload)
```
Internet → App Gateway WAF v2 (Online Spoke) → Internal Load Balancer → App VMs
           (Public IP on App Gateway only — no VM public IPs)
```

### East-West (Spoke → Spoke)
```
Spoke A → Hub VNet (via peering) → Azure Firewall (inspection) → Hub → Spoke B
```

### Outbound (Azure → Internet)
```
Spoke VMs → User-Defined Route (0.0.0.0/0 → Firewall) → Azure Firewall → Internet
            (No direct internet egress from spokes)
```

## Azure Firewall Premium Configuration

- **SKU**: Premium (required for IDPS and TLS inspection)
- **IDPS**: Alert and Deny mode for all categories
- **TLS Inspection**: Enabled for outbound HTTPS
- **Threat Intelligence**: Alert and Deny
- **DNS Proxy**: Enabled — all spoke VMs point to Firewall as DNS
- **Application Rules**: Allow-list based (default deny)
- **Network Rules**: Allow required Azure service tags + on-premises CIDRs
- **DNAT Rules**: None (no inbound internet to hub)

## Route Tables

### Hub Management Subnet → Internet via Firewall
```
0.0.0.0/0 → Azure Firewall private IP (10.0.0.4)
```

### Spoke → Force tunnel all traffic through Firewall
```
0.0.0.0/0 → Azure Firewall private IP (10.0.0.4)
10.0.0.0/8 → Azure Firewall private IP (10.0.0.4)  [RFC1918 via firewall]
```

## VPN Gateway

- **SKU**: VpnGw2AZ (Zone-redundant, active-active)
- **Generation**: Gen2
- **BGP**: Enabled (ASN 65515)
- **Mode**: Active-Active for high availability
- **Protocol**: IKEv2 preferred, IKEv1 fallback
- **DPD Timeout**: 45 seconds

## Azure Bastion

- **SKU**: Standard
- **Features**: Native client support, shareable links, IP-based connections
- **Scale**: 2 instances minimum (auto-scale to 50)
- **File Transfer**: Enabled
- **Copy-Paste**: Enabled

## DDoS Protection

- **Plan**: DDoS Network Protection (linked to Hub VNet)
- **Scope**: Protects all public IPs in linked VNets (including Online spoke)
- **Alerts**: Configured for all DDoS telemetry metrics
- **Rapid Response**: DDoS Rapid Response team contact configured

## Private DNS Architecture

All private endpoints resolve via Private DNS zones linked to the Hub VNet. Azure Firewall DNS Proxy forwards all DNS queries to Azure-provided DNS (168.63.129.16), which resolves private endpoints automatically.

```
Private DNS Zones (linked to Hub VNet):
├── privatelink.blob.core.windows.net
├── privatelink.queue.core.windows.net
├── privatelink.table.core.windows.net
├── privatelink.file.core.windows.net
├── privatelink.vaultcore.azure.net
├── privatelink.database.windows.net
├── privatelink.postgres.database.azure.com
├── privatelink.azurecr.io
├── privatelink.aks.azure.com
├── privatelink.servicebus.windows.net
├── privatelink.eventgrid.azure.net
├── privatelink.monitor.azure.com
├── privatelink.oms.opinsights.azure.com
└── privatelink.agentsvc.azure-automation.net
```

## NSG Design Principles

1. **Default deny all**: NSGs start with DenyAllInbound and DenyAllOutbound
2. **Explicit allow**: Only approved ports/protocols are opened
3. **No 0.0.0.0/0 inbound**: Public internet access only via App Gateway/Bastion
4. **NSG Flow Logs**: Enabled on all NSGs, stored in Storage Account, sent to Log Analytics
5. **Application Security Groups**: Used for app-tier to app-tier rules

## Governance Guardrails

- **Azure Policy**: `deny-public-ip` policy prevents rogue public IPs outside Online LZ
- **Azure Policy**: `deny-peering-to-non-approved-vnets` prevents unauthorized peering
- **Azure Policy**: `require-nsg-on-subnet` ensures all subnets have NSG attached
- **Azure Policy**: `audit-unrestricted-rdp-ssh` audits any NSG allowing 3389/22 from Internet
