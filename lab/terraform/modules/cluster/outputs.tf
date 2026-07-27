output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.lab.name
}

output "resource_group_name" {
  description = "Resource group holding the cluster"
  value       = azurerm_resource_group.cluster.name
}

output "node_resource_group" {
  description = "AKS-managed MC_* group — where the VMSS, LB and egress PIP live"
  value       = azurerm_kubernetes_cluster.lab.node_resource_group
}

output "kubelet_identity_object_id" {
  description = "Kubelet managed identity granted AcrPull"
  value       = azurerm_kubernetes_cluster.lab.kubelet_identity[0].object_id
}

output "get_credentials_command" {
  description = "Run this to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.cluster.name} --name ${azurerm_kubernetes_cluster.lab.name} --overwrite-existing"
}
