# terraform/environments/dev/backend.tf
terraform {
  backend "s3" {
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Replaces dynamodb_table
  }
}