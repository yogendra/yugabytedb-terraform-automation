terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    yb = {
      version = "~> 0.1.0"
      source  = "terraform.yugabyte.com/platform/yugabyte-platform"
    }
    http = {
      source  = "hashicorp/http"
      version = "2.1.0"
    }
  }
}

variable "yb_platform_ns" {
  type        = string
  description = "YugabyteDB Anywhere Namespace"
  default     = "yb-platform"
}
variable "yb_license_path" {
  type        = string
  description = "Absolute/Relative path of yb license file (k8s yaml)"
  default     = "./yugabyte-k8s-secret.yml"
}

variable "yb_login" {
  type        = string
  description = "YugabyteDB Anywhere Login Email"
  default     = "demo@yugabyte.com"
}
variable "yb_username" {
  type        = string
  description = "YugabyeDB Anywhere User Name"
  default     = "Yugabyte Demo User"
}
variable "yb_password" {
  type        = string
  description = "YugabyeDB Anywhere Password"
  default     = "YugabyteDB4Win!"
}
variable "kubeconfig_path" {
  description = "absolute/relative kubeconfig path"
  default     = "../../../gcp/gke/test/.kubeconfig"
  type        = string
}

resource "kubernetes_namespace" "yb_platform" {
  metadata {
    name = var.yb_platform_ns
  }
}

locals {
  yb_license = yamldecode(file(var.yb_license_path))
}
resource "kubernetes_secret" "yb_image_pull_secret" {
  depends_on = [
    kubernetes_namespace.yb_platform
  ]

  metadata {
    name      = local.yb_license.metadata.name
    namespace = kubernetes_namespace.yb_platform.id
  }
  binary_data = local.yb_license.data
  type        = "kubernetes.io/dockerconfigjson"
}

resource "helm_release" "yb_portal" {
  depends_on = [
    kubernetes_secret.yb_image_pull_secret
  ]

  name       = "yb-portal"
  repository = "https://charts.yugabyte.com"
  chart      = "yugaware"
  version    = "2.13.0"
  namespace  = kubernetes_namespace.yb_platform.id
  wait       = true

  set {
    name  = "yugaware.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "yugaware.resources.requests.cpu"
    value = "200m"
  }
  set {
    name  = "yugaware.resources.requests.memory"
    value = "2Gi"
  }
  set {
    name  = "yugaware.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "yugaware.resources.limits.memory"
    value = "2Gi"
  }
  set {
    name  = "prometheus.resources.requests.memory"
    value = "1Gi"
  }
  set {
    name  = "prometheus.resources.requests.cpu"
    value = "200m"
  }
  set {
    name  = "postgres.resources.requests.cpu"
    value = "200m"
  }
  set {
    name  = "postgres.resources.requests.memory"
    value = "1Gi"
  }
}
data "kubernetes_service" "yb_portal_lb" {
  depends_on = [
    helm_release.yb_portal
  ]
  metadata {
    namespace = kubernetes_namespace.yb_platform.id
    name      = "yb-portal-yugaware-ui"
  }
}
locals {
  yb_host = coalesce(data.kubernetes_service.yb_portal_lb.status.0.load_balancer.0.ingress.0.hostname, data.kubernetes_service.yb_portal_lb.status.0.load_balancer.0.ingress.0.ip)
  yb_port = data.kubernetes_service.yb_portal_lb.spec.0.port.0.port
  yb_api_endpoint = "${local.yb_host}:${local.yb_port}"
}



resource "time_sleep" "wait_for_yugaware" {
  depends_on = [helm_release.yb_portal]

  create_duration = "120s"
}

provider "yb" {
  alias = "unauthenticated"
  host = local.yb_api_endpoint
}
resource "yb_customer_resource" "customer" {
  provider   = yb.unauthenticated
  depends_on = [
    time_sleep.wait_for_yugaware
  ]
  code     = "admin"
  email    = var.yb_login
  name     = var.yb_username
  password = var.yb_password

}


################################################################################
## Temp -- Generate API token manually :: Start
resource "random_uuid" "temp_api_token" {
}
locals {
  yb_api_token = coalesce(yb_customer_resource.customer.api_token, random_uuid.temp_api_token.id)
}
resource "null_resource" "create_api_token" {
  count = yb_customer_resource.customer.api_token == ""? 1: 0
  depends_on = [
    yb_customer_resource.customer
  ]
  provisioner "local-exec" {
    command = "[[ -n '${yb_customer_resource.customer.api_token}' ]] || kubectl --kubeconfig ${var.kubeconfig_path} -n ${var.yb_platform_ns} exec  -it yb-portal-yugaware-0 -c postgres  -- psql -U postgres -d yugaware -c \"update users set api_token = '${local.yb_api_token}' where email = '${var.yb_login}';\" -qt"
  }
}

## Temp -- Generate API token manually :: End
################################################################################



output "yb_api_endpoint" {
  value = local.yb_api_endpoint
}
output "yb_api_token" {
  value = local.yb_api_token
}
