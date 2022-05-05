provider "google" {
  project = "yrampuria-yb"
  region  = "us-central1"
  zone    = "us-central1-c"
  alias = "main"
  
}
module "gcp_gke" {
  source = "../"
  providers = {
    google = google.main
  }
}

output "kubeconfig_path" {
  value = module.gcp_gke.kubeconfig_path
}
