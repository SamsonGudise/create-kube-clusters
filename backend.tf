terraform {
  backend "s3" {
    key            = "awsdemo/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
