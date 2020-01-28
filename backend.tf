terraform {
  backend "s3" {
    key            = "eks/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
  }
}
