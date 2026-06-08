# terraform/modules/karpenter/variables.tf
variable "cluster_name" { type = string }
variable "cluster_endpoint" { type = string }
variable "oidc_provider_arn" { type = string }
variable "node_iam_role_name" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "tags" { type = map(string) }