#
# Outputs
#

output "KUBECONFIG" {
  value = "${module.eks.kubeconfig}"
}

output "EKS-Cluster-Endpoint" {
  value = "${module.eks.cluster_endpoint}"
}

output "RDS-Endpoint" {
  description = "The connection endpoint"
  value       = "${module.db.this_db_instance_endpoint}"
}
