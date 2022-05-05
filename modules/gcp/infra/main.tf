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

data "http" "my_public_ip" {
  url = "https://ifconfig.me"
}

data "google_client_config" "provider" {

}

# Create VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = "${var.prefix}-network"
  auto_create_subnetworks = true
}

# Create Router
resource "google_compute_router" "router" {
  name    = "${var.prefix}-router"
  network = google_compute_network.vpc_network.id
  region = data.google_client_config.provider.region
  bgp {
    asn = 64514
  }
}


resource "google_compute_firewall" "allow_workstation" {
  name    = "allow-workstaton"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "all"
  }
  direction     = "INGRESS"
  source_ranges = ["${data.http.my_public_ip.body}"]


}
# Create NAT GW
resource "google_compute_router_nat" "nat" {
  name                               = "${var.prefix}-nat"
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  region = data.google_client_config.provider.region

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

data "google_compute_subnetwork" "primary_subnet" {
  name   = "${var.prefix}-network"
  region = data.google_client_config.provider.region
}



# Create GCP Service Account
# Create JSON for service account (Not Needed)

resource "google_service_account" "sa" {
  account_id   = "${var.prefix}-sa"
  display_name = "YugabyteDB Service Account (${var.prefix})"
}



resource "google_compute_instance" "jumpbox" {
  name         = "${var.prefix}-jumpbox"
  machine_type = "f1-micro"
  zone = data.google_client_config.provider.zone

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20220419"
    }
  }

  network_interface {
    # A default network is created for all GCP projects
    network    = google_compute_network.vpc_network.name
    subnetwork = data.google_compute_subnetwork.primary_subnet.name
    subnetwork_project = data.google_compute_subnetwork.primary_subnet.project
    access_config {
    }
  }
}


output "vpc" {
  value = google_compute_network.vpc_network.name
}

output "sa_account_id" {
  value       = google_service_account.sa.account_id
  description = "Service Account Name"
}


output "jumpbox" {
  value       = google_compute_instance.jumpbox.name
  description = "Jumpbox name"
}

