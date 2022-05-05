terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
    yb = {
      version = "~> 0.1.0"
      source  = "terraform.yugabyte.com/platform/yugabyte-platform"
    }
  }
}
variable "yb_api_endpoint"{
  type = string
  description = "Yugabyte Portal Address (hostname/ip address)"
}
variable "yb_api_token" {
  type        = string
  description = "API Key for Yugabyte"
}


variable "kubeconfig_path" {
  description = "absolute/relative kubeconfig path"
  default     = "../../../gcp/gke/test/.kubeconfig"
  type        = string
}
variable "yb_license_path" {
  type        = string
  description = "Absolute/Relative path of yb license file (k8s yaml)"
  default     = "./yugabyte-k8s-secret.yml"
}
variable "cloud_provider_config" {
  type = object({
    name = string,
    config = object({
      provider = string,
      registry = string
    })
    regions = map(object({
      name = string,
      code = string,
      lat = number,
      lon = number,
      zones = map(object({
        overrides = string
        domain = string
        sc = string
      }))
    }))
  })
  description = "Kubernetes config"
}
resource "kubernetes_namespace" "yb_deployment" {
  metadata {
    name = "yb-deploy"
  }
}

resource "kubernetes_service_account" "pum" {
  metadata {
    name      = "yugabyte-platform-universe-management"
    namespace = kubernetes_namespace.yb_deployment.id
  }
}
data "kubernetes_secret" "pum_secret" {
  metadata {
    name      = kubernetes_service_account.pum.default_secret_name
    namespace = kubernetes_namespace.yb_deployment.id
  }
}
resource "kubernetes_cluster_role_binding" "yb_pum_crb" {
  metadata {
    name = "yb-pum-crb"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.pum.metadata[0].name
    namespace = kubernetes_service_account.pum.metadata[0].namespace
  }
}




locals {

  yb_license_str =file(var.yb_license_path)
  yb_license = yamldecode(local.yb_license_str)
  kc          = yamldecode(file(var.kubeconfig_path))
  server      = local.kc.clusters[0].cluster.server
  server_cert = local.kc.clusters[0].cluster.certificate-authority-data

  pum_kubeconfig = {
    apiVersion = "v1"
    kind       = "Config"
    preferences = {
      colors = true
    }
    current-context = "yb-deploy"
    contexts = [
      {
        name = "yb-deploy"
        context = {
          cluster = "yb-deploy"
          user    = "yugabyte-platform-universe-management"
        }
      }
    ]
    clusters = [
      {
        name = "yb-deploy"
        cluster = {
          server                     = local.server
          certificate-authority-data = local.server_cert
        }
      }
    ]
    users = [
      {
        name = "yugabyte-platform-universe-management"
        user = {
          token = data.kubernetes_secret.pum_secret.data.token
        }
      }
    ]
  }
  pum_kubeconfig_str = yamlencode(local.pum_kubeconfig)
  cpc = var.cloud_provider_config

}

resource "local_file" "pum_kubeconfig" {
  content  = yamlencode(local.pum_kubeconfig)
  filename = "./yugabyte-platform-universe-management.conf"
}



provider "yb" {
  host = var.yb_api_endpoint
  api_token = var.yb_api_token
}




## This does not work yet.
resource "yb_cloud_provider" "kubernetes" {

  code = "kubernetes"
  name = local.cpc.name
  config = {
    KUBECONFIG_PROVIDER                = local.cpc.config.provider
    KUBECONFIG_SERVICE_ACCOUNT         = kubernetes_service_account.pum.metadata[0].name
    KUBECONFIG_IMAGE_REGISTRY          = local.cpc.config.registry
    KUBECONFIG_IMAGE_PULL_SECRET_NAME  = "yugabyte-k8s-pull-secret"
    KUBECONFIG_PULL_SECRET_NAME        = "yugabyte-k8s-pull-secret.yaml"
    KUBECONFIG_PULL_SECRET_CONTENT     = local.yb_license_str
  }

  dynamic "regions" {
    for_each = local.cpc.regions
    content {
      code = regions.value.code
      name = regions.value.name
      latitude = regions.value.lat
      longitude = regions.value.lon

      dynamic "zones" {
        for_each = regions.value.zones
        content {
          name = zones.key
          code = zones.key
          config = {
            STORAGE_CLASS = zones.value.sc
            OVERRIDES  = zones.value.overrides
            KUBE_DOMAIN = zones.value.domain
            KUBECONFIG_NAME = "${kubernetes_service_account.pum.metadata[0].name}.conf"
            KUBECONFIG_CONTENT = local.pum_kubeconfig_str
          }
        }
      }
    }
  }
}


# data "yb_provider_key" "kubernetes-key" {
#   provider_id = yb_cloud_provider.kubernetes.id
# }


locals {
  software_version = "2.13.1.0-b42"
}
resource "yb_universe" "test_locl_k8s" {
  depends_on = [yb_cloud_provider.kubernetes]
  clusters {
    cluster_type = "PRIMARY"
    user_intent {
      universe_name      = "test-k8s"
      provider_type      = "kubernetes"
      provider           = yb_cloud_provider.kubernetes.id
      region_list        = yb_cloud_provider.kubernetes.regions[*].uuid
      num_nodes          = 3
      replication_factor = 3
      instance_type      = "xsmall"
      device_info {
        num_volumes  = 1
        volume_size  = 10
        storage_type = "Persistent"
      }
      assign_public_ip              = false
      use_time_sync                 = true
      enable_ysql                   = true
      enable_node_to_node_encrypt   = false
      enable_client_to_node_encrypt = false
      yb_software_version           = local.software_version
      # access_key_code               = data.yb_provider_key.kubernetes-key.id
    }
  }
  communication_ports {}
}
