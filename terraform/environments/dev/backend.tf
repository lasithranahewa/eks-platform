# terraform/environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket       = "eks-platform-tfstate-923187443356"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Replaces dynamodb_table
  }
}