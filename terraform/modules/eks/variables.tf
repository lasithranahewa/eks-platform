# terraform/modules/eks/variables.tf
variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "intra_subnet_ids" { type = list(string) }
variable "enable_public_endpoint" { type = bool }
variable "public_access_cidrs" { type = list(string) }
variable "tags" { type = map(string) }

variable "access_entries" {
  description = "Map of access entries to add to the cluster"
  type        = any
  default     = {}
}