terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 1.19.0"
    }
  }
}
variable "prefix" {
  type        = string
  default     = "yb1"
  description = "Prefix for resources"
}
variable "vpc" {
  type = string
  description = "Name of the VPC netowk"
  default = "yb1-network"
}
variable "sa_account_id" {
  type = string
  default = "yb1-sa"
  description = "Service Accoutn ID to be used by Workers"
}
variable "gke_domain" {
  type        = string
  description = "DNS domain for GKE clusters"
  default     = "us-west1.yb"
}
variable "primary_master_cidr"{
  type = string
  description = "CIDR for masters"
  default = "172.16.0.32/28"
}
variable "primary_worker_cidr"{
  type = string
  description = "CIDR for workers"
  default = "10.2.0.0/16"
}

variable "primary_svc_cidr"{
  type = string
  description = "CIDR for Service"
  default = "10.72.0.0/20"
}
variable "primary_pod_cidr"{
  type = string
  description = "CIDR for Pods"
  default = "10.68.0.0/14"
}
variable "primary_machine_type" {
  type = string
  description = "Type of machine for Primary GKE"
  default = "e2-standard-8"
}
variable "primary_disk_type" {
  type = string
  description = "Type of Disk for Primary GKE"
  default = "pd-standard"
}
# variable "gcptoken_file" {
#   type        = string
#   description = "Path to GCP Token file"
#   default     = "./.gcptoken"
# }
variable "kubeconfig_file" {
  type        = string
  description = "Path to Kubeconfig Token file"
  default     = "./.kubeconfig"
}

data "google_client_config" "provider" {
}
data "google_compute_network" "vpc" {
  name = var.vpc
}
data "google_compute_zones" "primary_zone" {
  # project = data.google_client_config.provider.project
  region = data.google_client_config.provider.region
}

data "google_compute_subnetwork" "primary_subnet" {
  name   = data.google_compute_network.vpc.name
  region = data.google_client_config.provider.region
}

data "google_service_account" "sa"{
  account_id = var.sa_account_id
}


resource "google_compute_subnetwork" "primary_subnet" {
  name          = "${var.prefix}-primary-subnet"
  ip_cidr_range = var.primary_worker_cidr
  network       = data.google_compute_network.vpc.id
  secondary_ip_range {
    range_name    = "${var.prefix}-primary-svc-range"
    ip_cidr_range = var.primary_svc_cidr
  }

  secondary_ip_range {
    range_name    = "${var.prefix}-primary-pod-range"
    ip_cidr_range = var.primary_pod_cidr
  }
}


# Create GKE
resource "google_container_cluster" "primary" {
  name = "${var.prefix}-gke"
  location = data.google_client_config.provider.region
  node_locations = data.google_compute_zones.primary_zone.names
  default_max_pods_per_node = 110
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = data.google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.primary_subnet.id

  dns_config {
    cluster_dns        = "CLOUD_DNS"
    cluster_dns_scope  = "VPC_SCOPE"
    cluster_dns_domain = "${data.google_client_config.provider.region}.yb"

  }
  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.prefix}-primary-pod-range"
    services_secondary_range_name = "${var.prefix}-primary-svc-range"
  }
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = var.primary_master_cidr
  }
  release_channel {
    channel = "RAPID"
  }
}


# Create GKE Node Pool
resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "${var.prefix}-${data.google_client_config.provider.region}"
  cluster    = google_container_cluster.primary.id
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = var.primary_machine_type
    disk_type    = var.primary_disk_type
    disk_size_gb = "100"
    image_type   = "COS_CONTAINERD"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = data.google_service_account.sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }
}

# resource "local_file" "gcptoken" {
#   content         = data.google_client_config.provider.access_token
#   filename        = var.gcptoken_file
#   file_permission = "0600"
# }


locals {
  kubeconfig = {
    apiVersion = "v1"
    kind       = "Config"
    preferences = {
      colors = true
    }
    current-context = "${var.prefix}-primary-context"
    contexts = [
      {
        name = "${var.prefix}-primary-context"
        context = {
          cluster   = google_container_cluster.primary.name
          user      = data.google_service_account.sa.email
          namespace = "default"
        }
      }
    ]
    clusters = [
      {
        name = google_container_cluster.primary.name
        cluster = {
          server                     = "https://${google_container_cluster.primary.endpoint}"
          certificate-authority-data = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
        }
      }
    ]
    users = [
      {
        name = data.google_service_account.sa.email
        user = {
          auth-provider = {
            name = "gcp"
            config = {
              cmd-path   = "gcloud"
              cmd-args   = "config config-helper --format=json"
              expiry-key = "{.credential.token_expiry}"
              token-key  = "{.credential.access_token}"
            }
          }
        }
      }
    ]
  }
}

resource "local_file" "kubeconfig" {
  content         = yamlencode(local.kubeconfig)
  filename        = var.kubeconfig_file
  file_permission = "0600"

}

output "kubeconfig_path" {
  value = local_file.kubeconfig.filename
}


