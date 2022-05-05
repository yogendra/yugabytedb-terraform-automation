locals {
  kubeconfig_path = "./.kubeconfig"
  yb_license_path = "../../../../secrets/yugabyte-k8s-secret.yml"
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
  alias = "gke"
}

module "yb_configure_k8s_provider" {
  source = "../"
  kubeconfig_path = local.kubeconfig_path
  yb_license_path = local.yb_license_path
  yb_api_endpoint = "34.134.223.96:80"
  yb_api_token = "d5f80fcb-353e-f99d-884c-1126086f6ecf"

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
