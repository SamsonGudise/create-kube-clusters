module  "create-aks-cluster" {
    source = "azure"
}

module "create-gke-cluster" {
    source = "gcp"
    region = "us-west1"
    project_name = "kubernetes-176916"
}

module "create-eks-cluster" {
    source = "aws"
    vpc_id = "vpc-06a9c4a290bf59d6a"
    key_name = "sagudise"
    region = "us-east-1"
    cluster_name = "awsdemo"
}

output  "aks-kubeconfig" {
    value = "${module.create-aks-cluster.kubeconfig}"
}

output  "eks-kubeconfig" {
    value = "${module.create-eks-cluster.kubeconfig}"
}

output  "gke-kubeconfig" {
    value = "${module.create-gke-cluster.kubeconfig}"
}