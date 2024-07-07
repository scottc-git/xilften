provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-netflix"
    key            = "terraform/eks/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-lock-table-netflix"
    encrypt        = true
  }
}

data "aws_caller_identity" "current" {}

# Create OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["a031c46782e6e6c662c2c87c76da9aa62ccabd8e"]
}

# EKS Node Group IAM Role
module "eks_node_group_iam" {
  source = "../modules/iam-roles"

  role_name = "eks-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  policy_name = "eks-node-group-policy"
  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "eks:DescribeCluster",
          "eks:DescribeNodegroup",
          "eks:ListClusters",
          "eks:ListNodegroups",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      }
    ]
  })
}

# GitHub Actions IAM Role
module "github_actions_iam" {
  source = "../modules/iam-roles"

  role_name = "github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated : "${aws_iam_openid_connect_provider.github.arn}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition : {
          StringEquals : {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com",
            "token.actions.githubusercontent.com:sub" : "repo:scottc-git/xilften:ref:refs/heads/main"
          }
        }
      }
    ]
  })
  policy_name = "github-actions-policy"
  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          # EKS
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          
          # IAM
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:ListRolePolicies",
          "iam:GetOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
          "iam:DetachRolePolicy",
          "iam:CreateRole",
          "iam:ListInstanceProfilesForRole",
          
          # S3
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          
          # DynamoDB
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",

          # CloudWatch Logs
          "logs:CreateLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagResource",

          # EC2
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:DescribeVpcs",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:CreateRoute",
          "ec2:DescribeRouteTables",
          "ec2:AssociateRouteTable",
          "ec2:CreateSubnet",
          "ec2:DescribeSubnets",
          "ec2:CreateNatGateway",
          "ec2:DescribeNatGateways",
          "ec2:AllocateAddress",
          "ec2:DescribeAddresses",
          "ec2:CreateTags"
        ],
        Resource = [
          "arn:aws:s3:::terraform-state-bucket-netflix/*",
          "arn:aws:dynamodb:us-west-2:${data.aws_caller_identity.current.account_id}:table/terraform-lock-table-netflix",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-node-group-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/eks-node-group-policy",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/github-actions-policy",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com",
          "arn:aws:ec2:us-west-2:${data.aws_caller_identity.current.account_id}:elastic-ip/*",
          "arn:aws:ec2:us-west-2:${data.aws_caller_identity.current.account_id}:vpc/*",
          "arn:aws:logs:us-west-2:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/my-netflix-eks/*"
        ]
      }
    ]
  })
}
