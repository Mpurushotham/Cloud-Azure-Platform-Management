output "acr_name" {
  description = "Registry name — use with: az acr build --registry <name> ..."
  value       = module.registry.acr_name
}

output "acr_login_server" {
  description = "Registry FQDN for image references"
  value       = module.registry.login_server
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = module.cluster.cluster_name
}

output "node_resource_group" {
  description = "AKS-managed MC_* group (VMSS, load balancer, egress public IP)"
  value       = module.cluster.node_resource_group
}

output "next_steps" {
  description = "Copy-paste to get working"
  value       = <<-EOT

    1. Configure kubectl:
       ${module.cluster.get_credentials_command}

    2. Build an image server-side in ACR (no local Docker needed):
       az acr build --registry ${module.registry.acr_name} --image demo:v1 <path-with-Dockerfile>

    3. Deploy it — note there is NO imagePullSecret; the kubelet identity holds AcrPull:
       kubectl create deployment demo --image=${module.registry.login_server}/demo:v1
       kubectl expose deployment demo --type=LoadBalancer --port=80
       kubectl get svc demo -w        # wait for EXTERNAL-IP

    4. Pause between sessions (kills the node VM cost):
       bash lab/scripts/teardown.sh stop

    5. True zero when done:
       bash lab/scripts/teardown.sh destroy
  EOT
}
