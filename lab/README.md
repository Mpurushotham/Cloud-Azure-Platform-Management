# `lab/` — Free-tier automation practice

A deliberately small, destroyable Azure footprint for practising IaC automation:
**ACR + AKS + Log Analytics**, driven by Terraform.

This tree is **independent of the rest of the repository**. The enterprise design in
`governance/`, `networking/`, `security/`, `landing-zones/` is reference material — it assumes a
tenant-root management group hierarchy and ~$4,500/month of platform services. See
[`docs/architecture/free-tier-lab-plan.md`](../docs/architecture/free-tier-lab-plan.md) for the full
design, the diagrams, and the evidence behind that claim.

---

## Cost, stated plainly

**Out of pocket: $0.** The subscription has `spendingLimit: On`, so when the $200 credit is
exhausted Azure *disables* the subscription rather than charging anything.

**It does consume credit.** This is not the "always free" tier — AKS nodes cannot be, because the
always-free VM (`B1s`, 1 vCPU) is below AKS's 2-vCPU minimum. The control plane is free; the node
is not.

| Item | Rate | 3-hour session |
|---|---|---|
| AKS control plane (Free tier) | $0 | $0.00 |
| 1 × `Standard_D2as_v7` node (2 vCPU, 8 GiB) | ~$0.09/hr | ~$0.27 |
| Standard public IP (AKS egress) | ~$0.005/hr | ~$0.02 |
| ACR Basic | ~$0.167/day | ~$0.02 |
| 32 GiB managed disk | ~$0.0016/hr | ~$0.01 |
| Public IP per `LoadBalancer` Service | ~$0.005/hr | ~$0.02 |
| **Total** | | **≈ $0.34** |

≈ **$75/month** if you forget to tear down. The credit is not the constraint — forgetting is.

> Originally scoped for `Standard_B2s` at ~$0.042/hr. **This subscription is not offered any
> burstable SKU in eastus**, so the node is a `D2as_v7` instead — roughly twice the price, but with
> 8 GiB instead of 4 GiB. See "Free Trial restrictions" below.

> The $200 credit expires **30 days after signup regardless of use**. After that the subscription
> disables unless you upgrade to Pay-As-You-Go. Check remaining days in
> Portal → Cost Management + Billing → Credits.

---

## First run

## Free Trial restrictions discovered the hard way

Both of these passed every static check and only surfaced at apply time. Neither is documented as a
Free Trial limitation anywhere obvious.

| Restriction | Symptom | Workaround |
|---|---|---|
| **No burstable (B-series) VM SKUs** in eastus | `The VM size of Standard_B2s is not allowed in your subscription in location 'eastus'` — despite `standardBSFamily` quota showing 4 | Use `Standard_D2as_v7` (2 vCPU / 8 GiB). `preflight.sh` now checks SKU *availability*, not just quota |
| **ACR Tasks not permitted** | `TasksOperationsNotAllowed` on `az acr build` | Build locally and `docker push`. Requires `--platform linux/amd64` on Apple Silicon |
| `Microsoft.Consumption/budgets` unsupported | Billing-scope error | Spending limit + teardown discipline instead |

**Quota and availability are two independent gates.** Quota answers "how much may I use"; availability
answers "is this SKU offered to this subscription here at all". Checking only the first is what let
the first apply fail.

## First run

```bash
# 0. Preflight — read-only; refuses to proceed if anything would fail
bash lab/scripts/preflight.sh eastus Standard_D2as_v7

# 1. Register the providers it flags (one-time, ~1-2 min each)
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights

# 2. Re-run preflight until it passes
bash lab/scripts/preflight.sh eastus

# 3. Configure
cd lab/terraform/environments/lab
cp terraform.tfvars.example terraform.tfvars   # gitignored; edit if needed

# 4. Plan, read every line, then apply
terraform init
terraform plan
terraform apply        # ~5-8 min, mostly AKS
```

## Each practice session

```bash
cd lab/terraform/environments/lab
terraform apply                                   # or: az aks start (if you used 'stop')
terraform output -raw next_steps                  # copy-paste guide

# ... practise ...

bash lab/scripts/teardown.sh stop                 # pause: kills node cost, keeps cluster
bash lab/scripts/teardown.sh destroy              # true $0
```

**`stop` vs `destroy`** — worth internalising:

| | node VM | disk | public IP | ACR | Log Analytics |
|---|---|---|---|---|---|
| `az aks stop` | stopped ✅ | **still bills** | **still bills** | still bills | still bills |
| `terraform destroy` | gone ✅ | gone ✅ | gone ✅ | gone ✅ | gone ✅ |

`stop` is the cheap pause between sessions on the same day (restart ~2 min).
`destroy` is the only genuine zero.

---

## Layout

```
lab/
├── scripts/
│   ├── preflight.sh        # read-only assertions: quota, providers, spending limit
│   └── teardown.sh         # stop | destroy | nuke
└── terraform/
    ├── modules/
    │   ├── platform/       # RG + Log Analytics (daily ingestion cap)
    │   ├── registry/       # ACR Basic, admin user DISABLED
    │   └── cluster/        # VNet + AKS Free tier + AcrPull role assignment
    └── environments/lab/   # root module, local state (Phase 1)
```

## Design decisions worth understanding

| Decision | Why |
|---|---|
| `node_count = 1`, `Standard_B2s` | Regional quota is **4 vCPU**. AKS's default 3 × `DS2_v2` = 6 vCPU fails outright |
| `sku_tier = "Free"` | Control plane free; Standard adds ~$0.10/hr for an SLA a lab doesn't need |
| **Container Insights not enabled** | The single largest hidden cost in AKS labs — per-GB ingestion of all container stdout. Turn on deliberately in Phase 4 and measure |
| `daily_quota_gb = 1` on the workspace | The enterprise tree sets `dailyQuotaGb: -1` (uncapped). Not copied — uncapped ingestion on a credit budget is how you get surprised |
| ACR `admin_enabled = false` | Forces the correct auth path (kubelet managed identity + `AcrPull`) instead of the shared static credential every tutorial teaches |
| Five tags on everything | Matches `governance/policies/custom/require-tags.json`, so when you assign that Deny policy in Phase 3 nothing breaks |
| `10.50.0.0/16` | Outside the enterprise ranges (10.0 hub / 10.10 corp / 10.20 online) so the two designs can never be confused |
| Azure CNI **overlay** | Pod IPs come from `pod_cidr`, not the subnet — a /22 supports far more pods. Current Microsoft default recommendation |
| `azurerm ~> 4.0` | The enterprise tree pins `~> 3.90`, which is superseded. Not inherited |
| Local state in Phase 1 | Remote state is a bootstrap chicken-and-egg. Deferred to Phase 2 with OIDC, when CI actually needs shared state |

## Building and deploying an image

`az acr build` is blocked (ACR Tasks), so build locally:

```bash
az acr login --name $(terraform -chdir=lab/terraform/environments/lab output -raw acr_name)
ACR=$(terraform -chdir=lab/terraform/environments/lab output -raw acr_login_server)

# --platform is REQUIRED on Apple Silicon: the host is arm64, AKS nodes are amd64.
# Omit it and pods crash-loop with "exec format error".
docker build --platform linux/amd64 -t $ACR/demo:v1 lab/apps/demo
docker push $ACR/demo:v1

sed "s|ACR_LOGIN_SERVER|$ACR|" lab/apps/demo/k8s.yaml | kubectl apply -f -
kubectl get svc demo -w        # wait for EXTERNAL-IP
```

`az acr login` uses your Entra token, not an admin credential — the registry has
`admin_enabled = false`, so no registry username/password exists.

## Expected friction (each is a lesson)

- **`AcrPull` propagation delay.** The first pod pull right after `apply` can 401. That's RBAC
  replication, not misconfiguration. Wait a minute and let the kubelet retry.
- **`exec format error` on Apple Silicon.** You built arm64 for an amd64 node. Rebuild with
  `--platform linux/amd64`.
- **`Service type=LoadBalancer` stuck at `<pending>`.** Something is blocking public IP creation.
  In this lab it'll be quota; once you reach Phase 3 it'll be `deny-public-ip`.
- **Pods Pending with no obvious cause.** 2 vCPU total and system pods already reserve a chunk. Set
  `resources.requests` on your workloads (see `apps/demo/k8s.yaml`) so the scheduler can reason.
- **`terraform destroy` leaves the `MC_*` group briefly.** AKS deletes it asynchronously. Verify
  with `az group list -o table` before declaring victory.

## What comes next

Phases 2–5 (OIDC + CI/CD, subscription-scoped governance, observability, then fixing the enterprise
tree's real defects) are specified in
[`docs/architecture/free-tier-lab-plan.md`](../docs/architecture/free-tier-lab-plan.md).
