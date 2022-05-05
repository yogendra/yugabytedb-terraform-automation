provider "google" {
  project = "yrampuria-yb"
  region  = "us-central1"
  zone    = "us-central1-c"
  alias = "main"
}
module "gcp_infra" {
  source = "../"
  providers = {
    google = google.main
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
