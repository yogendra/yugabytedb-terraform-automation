locals {
  project_root = "../.."
  secrets_root = "${local.project_root}/secrets"
  prefix = "lab01"
  gcp_project = "yrampuria-yb"
  gcp_region = "us-central1"
  gcp_zone = "us-central1-c"
  gke_domain = "us-central1.yb"
  gke_master_cidr = "172.16.0.32/28"
  gke_worker_cidr = "10.1.0.0/16"
  gke_pod_cidr = "10.4.0.0/16"
  gke_svc_cidr = "10.5.0.0/16"
  kubeconfig_path = "${local.secrets_root}/gke.kubeconfig.yml"
  yb_license = file("${local.secrets_root}/yugabyte-k8s-secret.yml")
  gke_yb_pum_kubeconfig = "${local.secrets_root}/gke-yugabyte-platform-universe-management.conf"
  yb_username = "demo@yugabyte.com"
  yb_password = "Password#123"
}

provider "google" {
  project = local.gcp_project
  region  = local.gcp_region
  zone    = local.gcp_zone
  alias = "main"
}

module "gcp_infra" {
  source = "../../modules/gcp/infra"
  prefix = local.prefix
  create_all_subnet = false

  providers = {
    google = google.main
   }
}

module "gcp_gke" {
  source = "../../modules/gcp/gke"
  prefix = local.prefix
  vpc_id = module.gcp_infra.vpc_id
  sa_account_id = module.gcp_infra.sa_account_id
  gke_domain = local.gke_domain
  master_cidr = local.gke_master_cidr
  worker_cidr = local.gke_worker_cidr
  service_cidr = local.gke_svc_cidr
  pod_cidr = local.gke_pod_cidr
  providers = {
    google = google.main
  }
}
resource "local_file" "gke_kubeconfig" {
  depends_on = [
    module.gcp_gke
  ]
  content = yamlencode(module.gcp_gke.kubeconfig)
  filename = local.kubeconfig_path
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
  source = "../../modules/yb/k8s-yb-anywhere"
  kubeconfig_path = local_file.gke_kubeconfig.filename
  yb_k8s_secret = local.yb_license

  providers = {
    kubernetes = kubernetes.gke
    helm = helm.gke
   }

}


module "yb_configure_k8s_provider" {

  source = "../../modules/yb/yb-configure-k8s-provider"
  kubeconfig = module.gcp_gke.kubeconfig
  yb_k8s_secret = local.yb_license
  yb_api_endpoint = module.k8s_yb_anywhere.yb_api_endpoint
  yb_api_token =  module.k8s_yb_anywhere.yb_api_token

  cloud_provider_config = {
    name = "local-k8s"
    config = {
      provider = "gke"
      registry = "quay.io/yugabyte/yugabyte"
    }
    regions = {
      "us-central1" = {
        name = "US North"
        code = "us-north"
        lat = 42
        lon = -93
        zones = {
          "us-central1-a" = {
            overrides = ""
            domain = "us-central1.yb"
            sc = "premium-rwo"
          }
          "us-central1-b" = {
            overrides = ""
            domain = "us-central1.yb"
            sc = "premium-rwo"
          }
          "us-central1-c" = {
            overrides = ""
            domain = "us-central1.yb"
            sc = "premium-rwo"
          }
          "us-central1-f" = {
            overrides = ""
            domain = "us-central1.yb"
            sc = "premium-rwo"
          }
        }
      }
    }
  }
  providers = {
    kubernetes = kubernetes.gke
  }
}

output "sa_account_id" {
  value = module.gcp_infra.sa_account_id
}

output "vpc" {
  value = module.gcp_infra.vpc
}

output "jumpbox" {
  value = module.gcp_infra.jumpbox
}

output "yb_address" {
  value = module.k8s_yb_anywhere.yb_api_endpoint
}
