variable machine_type {
  default = "n1-standard-1"
}
variable project_name {}
variable region {
    default = "us-west1"
}
resource "google_container_cluster" "primary" {
  name     = "awsdemo-gke-cluster"
  location = "${var.region}"
  provider =  "google.gke"
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "awsdemo-node-pool"
  location   = "${var.region}"
  cluster    = "${google_container_cluster.primary.name}"
  provider =  "google.gke"
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "${var.machine_type}"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

locals {
   kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://${google_container_cluster.primary.endpoint}
    certificate-authority-data: ${google_container_cluster.primary.master_auth.0.client_certificate}
  name: awsdemo-gke
kind: Config
current-context: gke-cluster
contexts: [{name: gke-cluster, context: {cluster: awsdemo-gke, user: user-1}}]
users: [{name: user-1, user: {auth-provider: {name: gcp}}}]
KUBECONFIG
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}