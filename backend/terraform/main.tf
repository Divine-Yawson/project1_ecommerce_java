provider "aws" {
  region = var.aws_region
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"
  name                 = "${var.project_name}-vpc"
  cidr                 = var.vpc_cidr
  azs                  = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets       = var.public_subnets
  private_subnets      = var.private_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "19.0"
  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  cluster_endpoint_public_access = true
  # Enable OIDC provider for IAM roles
  enable_irsa = true
  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      max_size       = 3
      min_size       = 2
      name           = "${var.project_name}-nodes"
    }
  }
}