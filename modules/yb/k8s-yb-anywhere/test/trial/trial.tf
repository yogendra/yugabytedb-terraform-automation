variable "list" {
  type    = list(string)
  default = ["us-central1-a", "us-central1-b", "us-central1-c", "us-central1-f", ]
}


locals {
  kubeconfig = {
    type = "Config"
    version = "v1"
    clusters = [
      {
        name = "cluster1"
      }
    ]
    contexts = [
      {
        name = "context1"
        cluster = "cluster1"
        user = "user1"
      }
    ]
    current-context = "context1"
    users = [
      {
        name = "user1"
        user = {
          token = "foobar"
        }
      }
    ]
  }
  regions = [
    { name: "us-central", zones : ["us-central-1a", "us-central-1b", "us-central-1c"]}
  ]

  local_k8s = {
     config = {
      KUBECONFIG_PROVIDER = "gke"
      KUBECONFIG_SERVICE_ACCOUNT = "yugabyte-platform-universe-management"
      KUBECONFIG_IMAGE_REGISTRY = "quay.io/yugabyte/yugabyte"
      KUBECONFIG_IMAGE_PULL_SECRET_NAME = "yugabyte-k8s-pull-secret"
      KUBECONFIG_PULL_SECRET_NAME = "yugabyte-k8s-pull-secret.yaml"
      KUBECONFIG_PULL_SECRET_CONTENT = yamlencode(local.kubeconfig)
    }
    regionList = [
      {

        name = "us-central"
        code = "us-central"
        zoneList = [
          {
            name = "us-central1-a"
            code = "us-central1-a"
            config = {
              STORAGE_CLASS =  "premium-rwo"
              OVERRIDES =  ""
              KUBECONFIG_NAME =  "yugabyte-platform-universe-management.conf"
              KUBECONFIG_CONTENT =  yamlencode(local.kubeconfig)
              KUBE_DOMAIN =  "yb1.yrampuria"
            }
          }
        ]
      }
    ]
  }
}

data "null_data_source" "yb_region" {
  for_each = local.regions
  inputs {
    name = each.name
    code = each.code
    for_each each.zones:
  }

}

output "config" {
  value = jsonencode(local.local_k8s)
}



