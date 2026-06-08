# terraform/modules/eks/main.tf

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version # "1.29"

  # Private endpoint only for security (no public API access in prod)
  # In dev, enable public for convenience
  cluster_endpoint_public_access       = var.enable_public_endpoint
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.public_access_cidrs

  # VPC Configuration
  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids # Worker nodes in private subnets
  control_plane_subnet_ids = var.intra_subnet_ids   # Control plane ENIs in intra subnets

  # Security: Enable Secrets encryption with AWS KMS
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks.arn
  }

  # Cluster Add-ons — managed by AWS, auto-updated
  cluster_addons = {
    # CoreDNS for service discovery
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType = "Fargate" # Optional: run CoreDNS on Fargate
      })
    }

    # VPC CNI for pod networking
    vpc-cni = {
      most_recent              = true
      before_compute           = true # Must be installed before worker nodes
      service_account_role_arn = module.vpc_cni_irsa_role.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Enable prefix delegation for more IPs per node (important for scale)
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }

    # kube-proxy for networking rules
    kube-proxy = {
      most_recent = true
    }

    # EBS CSI driver for persistent volumes
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }

    # Pod identity for IRSA v2
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # ─── Node Groups ─────────────────────────────────────────────────────────
  # System nodes: stable, on-demand, for platform tooling
  eks_managed_node_groups = {
    system = {
      name                     = "system"                          # Shortened to prevent length issues
      iam_role_use_name_prefix = false                             # Disables the 38-character prefix limit
      iam_role_name            = "${var.cluster_name}-system-role" # Explicitly named
      instance_types           = ["m5.large"]
      capacity_type            = "ON_DEMAND"
      min_size                 = 2
      max_size                 = 4
      desired_size             = 2

      # Use AL2023 — latest Amazon Linux optimized for K8s
      ami_type = "AL2023_x86_64_STANDARD"

      # Labels and taints to dedicate nodes to system workloads
      labels = {
        "node.kubernetes.io/purpose" = "system"
        "workload-type"              = "system"
      }
      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]

      # Block device — encrypted EBS root volume
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Latest launch template with IMDSv2 enforced
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required" # IMDSv2 — security best practice
        http_put_response_hop_limit = 1
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }
    }
  }

  # Grant cluster creator admin access
  enable_cluster_creator_admin_permissions = true

  # Access entries for team members (EKS API auth mode)
  access_entries = var.access_entries

  # Node security group — additional rules
  node_security_group_additional_rules = {
    # Allow all traffic between nodes (required for Karpenter + some CNI configs)
    ingress_self_all = {
      description = "Node to node all traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Karpenter webhook
    # ingress_karpenter_webhook = {
    #   description                   = "Karpenter webhook"
    #   protocol                      = "tcp"
    #   from_port                     = 8443
    #   to_port                       = 8443
    #   type                          = "ingress"
    #   source_cluster_security_group = true
    # }
  }

  tags = merge(var.tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })
}

# ─── KMS Key for Secrets Encryption ──────────────────────────────────────────
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key — ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-eks-secrets"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks-secrets"
  target_key_id = aws_kms_key.eks.key_id
}

# ─── IRSA for VPC CNI ─────────────────────────────────────────────────────────
module "vpc_cni_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-vpc-cni"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
  tags = var.tags
}

# ─── IRSA for EBS CSI Driver ─────────────────────────────────────────────────
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  tags = var.tags
}