#
# Provider Configuration
#

provider "aws" {
  version = ">= 2.28.1"
  region  = var.aws_region
}

data "aws_eks_cluster_auth" "dockup" {
  name = var.project_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.dockup.token
  load_config_file       = false
}
