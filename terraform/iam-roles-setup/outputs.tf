output "eks_node_group_role_arn" {
  value = module.eks_node_group_iam.role_arn
}

output "github_actions_role_arn" {
  value = module.github_actions_iam.role_arn
}

output "my_aws_admin_role_arn" {
  value = module.my_aws_admin_iam.role_arn
}
