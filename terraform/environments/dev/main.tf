# terraform/environments/dev/main.tf
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.28"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    # kubectl provider removed (unused)
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# Kubernetes provider — uses EKS token (no kubeconfig file needed)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "eks-platform-${var.environment}"
  common_tags = {
    Project     = "eks-platform"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCenter  = "platform-engineering"
  }
}

# ─── VPC ─────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  name         = local.cluster_name
  cluster_name = local.cluster_name
  vpc_cidr     = var.vpc_cidr

  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnet_cidrs = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
  public_subnet_cidrs  = ["10.0.96.0/24", "10.0.97.0/24", "10.0.98.0/24"]
  intra_subnet_cidrs   = ["10.0.99.0/28", "10.0.99.16/28", "10.0.99.32/28"]

  # Dev cost savings: single NAT gateway (~$33/month vs $99/month for 3)
  single_nat_gateway = true

  tags = local.common_tags
}

# ─── EKS Cluster ─────────────────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  intra_subnet_ids   = module.vpc.intra_subnet_ids

  # Dev: public endpoint for easy access; prod: false
  enable_public_endpoint = var.environment == "dev"
  public_access_cidrs    = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"] # Restrict to private subnet ranges

  tags = local.common_tags
}

# ─── Karpenter ───────────────────────────────────────────────────────────────
module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name       = module.eks.cluster_name
  cluster_endpoint   = module.eks.cluster_endpoint
  oidc_provider_arn  = module.eks.oidc_provider_arn
  node_iam_role_name = module.eks.cluster_name
  private_subnet_ids = module.vpc.private_subnet_ids

  tags = local.common_tags

  depends_on = [module.eks]
}

// ─── AWS Load Balancer Controller ─────────────────────────────────────────

# IRSA for AWS Load Balancer Controller
module "aws_lb_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${local.cluster_name}-aws-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  tags = local.common_tags
}

# Install via Helm with Terraform
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_lb_controller_irsa_role.iam_role_arn
  }

  depends_on = [module.eks]
}