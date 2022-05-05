locals {
  kubeconfig_path = "./.kubeconfig"
  yb_license_path = "../../../../secrets/yugabyte-k8s-secret.yml"
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
  alias = "gke"
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
  alias = "gke"
}

module "k8s_yb_anywhere" {
  source = "../"
  kubeconfig_path = local.kubeconfig_path
  yb_license_path = local.yb_license_path

  providers = {
    kubernetes = kubernetes.gke
    helm = helm.gke
   }

}

output "yb_api_endpoint" {
  value = module.k8s_yb_anywhere.yb_api_endpoint
}
output "yb_api_token" {
  value = module.k8s_yb_anywhere.yb_api_token
}
