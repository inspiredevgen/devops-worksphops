output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  value = { for e, r in aws_iam_role.apply : e => r.arn }
}

# EN: Copy-paste into a terminal where `gh` is logged in. These are VARIABLES, not secrets:
#     a role ARN is useless without a token GitHub signs for YOUR repo.
# FR : À coller dans un terminal où `gh` est connecté. Ce sont des VARIABLES, pas des secrets :
#     un ARN de rôle est inutile sans un jeton que GitHub signe pour VOTRE dépôt.
output "gh_variable_commands" {
  value = join("\n", concat(
    [
      "gh variable set AWS_ENABLED --repo ${var.github_repo} --body true",
      "gh variable set AWS_REGION --repo ${var.github_repo} --body ${var.aws_region}",
      "gh variable set TF_STATE_BUCKET --repo ${var.github_repo} --body ${local.state_bucket}",
      "gh variable set AWS_PLAN_ROLE_ARN --repo ${var.github_repo} --body ${aws_iam_role.plan.arn}",
    ],
    [for e, r in aws_iam_role.apply : "gh variable set AWS_APPLY_ROLE_ARN_${upper(e)} --repo ${var.github_repo} --body ${r.arn}"]
  ))
}
