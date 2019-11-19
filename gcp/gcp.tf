provider "google" {
  credentials = "${file("gcp-account.json")}"
  project     = "${var.project_name}"
  region      = "${var.region}"
  alias       = "gke"
}
