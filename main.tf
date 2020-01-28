module "create-eks-cluster" {
    source = "./aws"
    vpc_id = "vpc-0feed0fdaa8816ff0"
    key_name = "sgudise"
    region = "us-west-2"
    cluster_name = "eks-1"
}

output  "eks-kubeconfig" {
    value = "${module.create-eks-cluster.kubeconfig}"
}