module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true

  bootstrap_self_managed_addons = true

  cluster_addons = {
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    main = {
      name = "eks-nodes"
      
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      tags = {
        Environment = var.environment
        Terraform   = "true"
      }
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Project     = "microservices-demo"
  }
}

# CoreDNS addon - depends on node group
resource "aws_eks_addon" "coredns" {
  depends_on = [module.eks.eks_managed_node_groups]

  cluster_name  = module.eks.cluster_name
  addon_name    = "coredns"
  addon_version = "v1.11.3-eksbuild.2"
}
