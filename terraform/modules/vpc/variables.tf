# terraform/modules/vpc/variables.tf
variable "name" { type = string }
variable "cluster_name" { type = string }

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }

variable "intra_subnet_cidrs" {
  type    = list(string)
  default = []
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}