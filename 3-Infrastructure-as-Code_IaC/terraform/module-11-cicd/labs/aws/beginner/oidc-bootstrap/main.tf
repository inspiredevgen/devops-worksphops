# =============================================================================
# Lab 11.B-AWS — Keyless CI: GitHub Actions → AWS with OIDC
# Lab 11.B-AWS — CI sans clé : GitHub Actions → AWS avec OIDC
#
#   GitHub job ──(signed OIDC token: repo, branch, environment…)──► AWS STS
#   STS checks the role's TRUST POLICY against the token's claims ──► 1-hour credentials
#   GitHub ──(jeton OIDC signé : dépôt, branche, environnement…)──► AWS STS
#   STS compare la POLITIQUE DE CONFIANCE du rôle aux revendications du jeton ──► identifiants d'1 heure
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  issuer       = "token.actions.githubusercontent.com"
  account_id   = data.aws_caller_identity.current.account_id
  partition    = data.aws_partition.current.partition
  state_bucket = coalesce(var.state_bucket, "tfstate-${local.account_id}-${var.aws_region}")
  state_arn    = "arn:${local.partition}:s3:::${local.state_bucket}"
  prefixes     = concat([var.state_prefix], var.extra_state_prefixes)
  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.issuer}"

  # EN: WHO may assume each role = which token "sub" (subject) values are accepted.
  #     Plan: pull requests + the main branch (drift checks). Apply: ONE GitHub environment each.
  # FR : QUI peut assumer chaque rôle = quelles valeurs « sub » (sujet) du jeton sont acceptées.
  #     Plan : pull requests + la branche main (détection de dérive). Apply : UN environnement GitHub chacun.
  plan_subjects = [
    "repo:${var.github_repo}:pull_request",
    "repo:${var.github_repo}:ref:refs/heads/main",
  ]
  apply_subjects = { for e in var.environments : e => ["repo:${var.github_repo}:environment:${e}"] }

  trust = { for name, subjects in merge({ plan = local.plan_subjects }, local.apply_subjects) : name => jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "GitHubActionsOIDC"
      Effect    = "Allow"
      Principal = { Federated = local.provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.issuer}:aud" = "sts.amazonaws.com"
          "${local.issuer}:sub" = subjects # EN: exact match, no wildcards / FR : égalité exacte, sans jokers
        }
      }
    }]
  }) }

  # EN: Plan may READ any state under the prefix and create/delete the LOCK file, nothing else.
  # FR : Plan peut LIRE l'état sous le préfixe et créer/supprimer le fichier de VERROU, rien d'autre.
  plan_state_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ListStatePrefix"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = local.state_arn
        Condition = { StringLike = { "s3:prefix" = [for p in local.prefixes : "${p}/*"] } }
      },
      {
        Sid      = "ReadState"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = [for p in local.prefixes : "${local.state_arn}/${p}/*"]
      },
      {
        Sid      = "LockOnly"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = [for p in local.prefixes : "${local.state_arn}/${p}/*.tflock"]
      },
    ]
  })

  # EN: Apply for environment E: its OWN state file, and only resources named tf-cicd-E-*.
  # FR : Apply pour l'environnement E : SON fichier d'état, et seulement les ressources nommées tf-cicd-E-*.
  apply_policy = { for e in var.environments : e => jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ListOwnState"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = local.state_arn
        Condition = { StringLike = { "s3:prefix" = [for p in local.prefixes : "${p}/${e}.tfstate*"] } }
      },
      {
        Sid      = "OwnStateAndLock"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = flatten([for p in local.prefixes : ["${local.state_arn}/${p}/${e}.tfstate", "${local.state_arn}/${p}/${e}.tfstate.tflock"]])
      },
      {
        Sid      = "AppBuckets"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = ["arn:${local.partition}:s3:::tf-cicd-${e}-*", "arn:${local.partition}:s3:::tf-cicd-${e}-*/*"]
      },
      {
        Sid      = "AppParameters"
        Effect   = "Allow"
        Action   = "ssm:*"
        Resource = "arn:${local.partition}:ssm:${var.aws_region}:${local.account_id}:parameter/tf-cicd/${e}/*"
      },
      {
        Sid      = "DescribeParameters"
        Effect   = "Allow"
        Action   = "ssm:DescribeParameters"
        Resource = "*"
      },
    ]
  }) }
}

# EN: One per AWS account. AWS validates GitHub's certificate itself, so no thumbprint is needed.
# FR : Un par compte AWS. AWS valide lui-même le certificat de GitHub : aucune empreinte n'est requise.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.issuer}"
  client_id_list = ["sts.amazonaws.com"]
}

# ------------------------------------------------------------------------ plan
resource "aws_iam_role" "plan" {
  name                 = "tf-gha-plan"
  description          = "GitHub Actions: terraform plan for ${var.github_repo}"
  assume_role_policy   = local.trust["plan"]
  max_session_duration = 3600
}

# EN: Read everything (to refresh), write nothing. / FR : Tout lire (pour rafraîchir), ne rien écrire.
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform-state-read-and-lock"
  role   = aws_iam_role.plan.id
  policy = local.plan_state_policy
}

# ----------------------------------------------------------------------- apply
resource "aws_iam_role" "apply" {
  for_each = var.environments

  name                 = "tf-gha-apply-${each.key}"
  description          = "GitHub Actions: terraform apply for ${var.github_repo}, environment ${each.key}"
  assume_role_policy   = local.trust[each.key]
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "apply" {
  for_each = var.environments

  name   = "terraform-apply-${each.key}"
  role   = aws_iam_role.apply[each.key].id
  policy = local.apply_policy[each.key]
}

resource "aws_iam_role_policy_attachment" "apply_extra" {
  for_each = { for pair in flatten([
    for e, arns in var.extra_apply_policy_arns : [for a in arns : { env = e, arn = a }] if contains(var.environments, e)
  ]) : "${pair.env}|${pair.arn}" => pair }

  role       = aws_iam_role.apply[each.value.env].name
  policy_arn = each.value.arn
}
