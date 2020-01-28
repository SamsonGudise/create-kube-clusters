
#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EC2 Security Group to allow networking traffic
#  * Data source to fetch latest EKS worker AMI
#  * AutoScaling Launch Configuration to configure worker instances
#  * AutoScaling Group to launch worker instances
#

resource "aws_iam_role" "eks1-node" {
  name = "terraform-eks-eks1-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}


resource "aws_iam_role_policy_attachment" "eks1-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       =  aws_iam_role.eks1-node.name
}

resource "aws_iam_role_policy_attachment" "eks1-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks1-node.name
}

resource "aws_iam_role_policy_attachment" "eks1-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks1-node.name
}

resource "aws_iam_instance_profile" "eks1-node" {
  name = "terraform-eks-eks-1"
  role = aws_iam_role.eks1-node.name
}

resource "aws_security_group" "eks1-node" {
  name        = "terraform-eks-eks1-node"
  description = "Security group for all nodes in the cluster"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = map(
     "Name", "terraform-eks-eks1-node",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
    )
}

resource "aws_security_group_rule" "eks1-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks1-node.id
  source_security_group_id = aws_security_group.eks1-node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks1-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks1-node.id
  source_security_group_id = aws_security_group.eks-sg.id
  to_port                  = 65535
  type                     = "ingress"
}

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-1.14-*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon Account ID
}


# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml
locals {
  eks1-node-userdata = <<USERDATA
#!/bin/bash -xe
/etc/eks/bootstrap.sh ${var.cluster_name}
mkdir -p /etc/cni/net.d/
cat<<EOF>/etc/cni/net.d/10-aws.conflist
{
  "name": "aws-cni",
  "plugins": [
    {
      "name": "aws-cni",
      "type": "aws-cni",
      "vethPrefix": "eni"
    },
    {
      "type": "portmap",
      "capabilities": {"portMappings": true},
      "snat": true
    }
  ]
}
EOF
systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet
USERDATA
}

resource "aws_launch_configuration" "eks-1" {
  iam_instance_profile        = aws_iam_instance_profile.eks1-node.name
  image_id                    = data.aws_ami.eks-worker.id
  instance_type               = "m4.large"
  name_prefix                 = "terraform-eks-eks-1"
  key_name                    = var.key_name
  security_groups             = ["${aws_security_group.eks1-node.id}"]
  user_data_base64            = base64encode(local.eks1-node-userdata)
  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "eks-1" {
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.eks-1.id
  max_size             = 2
  min_size             = 1
  name                 = "terraform-eks-eks-1"

  vpc_zone_identifier = data.aws_subnet_ids.private.ids

  tag {
    key                 = "Name"
    value               = "eks-worker-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}