variable cluster_name {}
variable region {
    default = "us-east-1"
}
variable vpc_id {}
variable key_name {}
data "aws_vpc" "selected" {
  provider = "aws.eks"
  id = "${var.vpc_id}"
}

data "aws_subnet_ids" "private" {
  provider = "aws.eks"
  vpc_id = "${var.vpc_id}"

  tags = {
    SubnetType = "Private"
  }
}

resource "aws_security_group_rule" "eks-sg-ingress-cluster" {
  provider = "aws.eks"
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 0
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-sg.id}"
  source_security_group_id = "${aws_security_group.demo-node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group" "eks-sg" {
  provider = "aws.eks"
  name        = "terraform-eks-cluster"
  description = "Security group for cluster"
  vpc_id = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "terraform-eks-cluster",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
    )
  }"
}

resource "aws_iam_role" "demo-cluster" {
  provider = "aws.eks"
  name = "terraform-eks-demo-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "demo-cluster-AmazonEKSClusterPolicy" {
  provider = "aws.eks"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.demo-cluster.name}"
}

resource "aws_iam_role_policy_attachment" "demo-cluster-AmazonEKSServicePolicy" {
  provider = "aws.eks"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.demo-cluster.name}"
}

resource "aws_eks_cluster" "awsdemo" {
  provider = "aws.eks"
  name     = "${var.cluster_name}"
  role_arn       = "${aws_iam_role.demo-cluster.arn}"

  vpc_config {
    subnet_ids = ["${data.aws_subnet_ids.private.ids}"]
    security_group_ids = ["${aws_security_group.eks-sg.id}"]
  }
}


locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.awsdemo.endpoint}
    certificate-authority-data: ${aws_eks_cluster.awsdemo.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster_name}"
KUBECONFIG
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}