#
# Outputs
#

output "DOCKUP_OUTPUT_KUBECONFIG" {
  value = "${module.eks.kubeconfig}"
}

output "DOCKUP_OUTPUT_EKS_ENDPOINT" {
  value = "${module.eks.cluster_endpoint}"
}

output "DOCKUP_OUTPUT_DB_HOST" {
  description = "The connection endpoint"
  value       = "${module.db.this_db_instance_endpoint}"
}
