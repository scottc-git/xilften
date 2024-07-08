provider "aws" {
  region = "us-west-2"
}

terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.57"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-bucket-netflix"
    key            = "terraform/eks/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-lock-table-netflix"
    encrypt        = true
  }
}

# Reference the existing OIDC provider
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::767397667217:oidc-provider/token.actions.githubusercontent.com"
}


# https://github.com/terraform-aws-modules/terraform-aws-vpc?tab=readme-ov-file#external-nat-gateway-ips
resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"
}

# Create VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  #   version = "5.9.0"

  name = "my-netflix-vpc"
  cidr = "10.0.0.0/16"

  azs = ["us-west-2a", "us-west-2b", "us-west-2c"]

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway  = true
  single_nat_gateway  = false
  reuse_nat_ips       = true             # <= Skip creation of EIPs for the NAT Gateways
  external_nat_ip_ids = aws_eip.nat.*.id # <= IPs specified here as input to the module

  tags = {
    Name        = "my-netflix-vpc"
    Environment = "Production"
  }
}

# Create EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-netflix-eks"
  cluster_version = "1.30"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    eks_nodes = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]

      desired_size = 2
      min_size     = 1
      max_size     = 2

      iam_role_arn = var.eks_node_group_role_arn
    }
  }
}

