variable cluster_name {}
variable region {
    default = "us-west-2"
}
variable vpc_id {}
variable key_name {}
data "aws_vpc" "selected" {
  id = "${var.vpc_id}"
}

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id

  tags = {
    SubnetTier = "Private"
  }
}

resource "aws_security_group_rule" "eks-sg-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 0
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-sg.id
  source_security_group_id = aws_security_group.eks1-node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group" "eks-sg" {
  name        = "terraform-eks-cluster"
  description = "Security group for cluster"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = map(
     "Name", "terraform-eks-cluster",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
    )
}

resource "aws_iam_role" "eks-1-cluster" {
  name = "terraform-eks-eks-1-cluster"

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

resource "aws_iam_role_policy_attachment" "eks-1-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-1-cluster.name
}

resource "aws_iam_role_policy_attachment" "eks-1-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-1-cluster.name
}

resource "aws_eks_cluster" "awseks-1" {
  name     = var.cluster_name
  role_arn       = aws_iam_role.eks-1-cluster.arn
  version   = "1.14"
  vpc_config {
    subnet_ids = data.aws_subnet_ids.private.ids
    security_group_ids = ["${aws_security_group.eks-sg.id}"]
  }
}


locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.awseks-1.endpoint}
    certificate-authority-data: ${aws_eks_cluster.awseks-1.certificate_authority.0.data}
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