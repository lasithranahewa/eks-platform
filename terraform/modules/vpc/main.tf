# terraform/modules/vpc/main.tf
# Uses the official AWS VPC Terraform module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = var.name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs
  intra_subnets   = var.intra_subnet_cidrs # For EKS control plane ENIs

  # High Availability NAT — one per AZ (more expensive but production-grade)
  # Set to false and use single_nat_gateway = true for dev cost savings
  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway # true in dev, false in prod
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_vpn_gateway = false

  # DNS settings required for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required by EKS for subnet discovery
  # EKS uses these to automatically find subnets for load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    # Required for Karpenter subnet discovery
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# VPC Flow Logs for security auditing
resource "aws_flow_log" "main" {
  vpc_id          = module.vpc.vpc_id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/flowlogs/${var.name}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_iam_role" "flow_log" {
  name = "${var.name}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "flow_log" {
  role       = aws_iam_role.flow_log.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}