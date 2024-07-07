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
          # IAM
          "iam:*",

          # S3
          "s3:*",

          # DynamoDB
          "dynamodb:*",

          # CloudWatch Logs
          "logs:*",

          # EC2
          "ec2:*",

          # EKS
          "eks:*",

          # KMS
          "kms:*",

          # STS
          "sts:AssumeRole"
        ],
        Resource = "*"
      }
    ]
  })
}
