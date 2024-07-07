resource "aws_iam_role" "role" {
  name               = var.role_name
  assume_role_policy = var.assume_role_policy
}

resource "aws_iam_policy" "policy" {
  name        = var.policy_name
  description = "Policy for ${var.role_name}"
  policy      = var.policy_document
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

output "role_arn" {
  value = aws_iam_role.role.arn
}
