# -----------------------------------------------------------------------------
# Lab 0.I-AWS — A least-privilege IAM role for Terraform
# Lab 0.I-AWS — Un rôle IAM à moindre privilège pour Terraform
#
# EN: Instead of running Terraform as an all-powerful admin, we create a role
#     with PowerUserAccess (everything except most IAM) + a narrowly scoped IAM
#     policy that only allows managing IAM roles/policies whose names start
#     with the "tf-" prefix. Cost: $0 (IAM is free).
# FR: Au lieu d'exécuter Terraform en tant qu'administrateur tout-puissant, nous
#     créons un rôle avec PowerUserAccess (tout sauf la plupart d'IAM) + une
#     politique IAM restreinte qui n'autorise que les rôles/politiques dont le
#     nom commence par « tf- ». Coût : 0 $ (IAM est gratuit).
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # EN: If no principals are given, trust the account root (delegates the
  #     decision to IAM policies inside the account).
  # FR: Si aucun principal n'est fourni, faire confiance à la racine du compte
  #     (la décision est déléguée aux politiques IAM du compte).
  trusted_principals = length(var.trusted_principal_arns) > 0 ? var.trusted_principal_arns : [
    "arn:${local.partition}:iam::${local.account_id}:root"
  ]

  iam_arn_base = "arn:${local.partition}:iam::${local.account_id}"
}

# -----------------------------------------------------------------------------
# EN: Trust policy — WHO can assume the role.
# FR: Politique d'approbation — QUI peut assumer le rôle.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowTrustedPrincipalsToAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = local.trusted_principals
    }
  }
}

resource "aws_iam_role" "terraform" {
  name                 = var.role_name
  description          = "Terraform course role - least privilege / Rôle du cours Terraform"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_hours * 3600
}

# EN: AWS-managed policy: full access to services EXCEPT IAM/Organizations.
# FR: Politique gérée par AWS : accès complet aux services SAUF IAM/Organizations.
resource "aws_iam_role_policy_attachment" "power_user" {
  role       = aws_iam_role.terraform.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/PowerUserAccess"
}

# -----------------------------------------------------------------------------
# EN: Scoped IAM permissions — later modules need to create IAM roles (e.g. for
#     EC2 instance profiles), but only with the "tf-" prefix.
# FR: Permissions IAM restreintes — les modules suivants doivent créer des rôles
#     IAM (ex. profils d'instance EC2), mais seulement avec le préfixe « tf- ».
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "scoped_iam" {
  # EN: Read-only IAM visibility (needed for plans/refreshes).
  # FR: Lecture seule sur IAM (nécessaire pour les plans/rafraîchissements).
  statement {
    sid       = "IamReadOnly"
    effect    = "Allow"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  # EN: Manage ONLY prefixed roles, policies and instance profiles.
  # FR: Gérer UNIQUEMENT les rôles, politiques et profils d'instance préfixés.
  statement {
    sid    = "ManagePrefixedIamResources"
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy", "iam:UntagPolicy",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile", "iam:UntagInstanceProfile",
      "iam:PassRole",
    ]
    resources = [
      "${local.iam_arn_base}:role/${var.iam_name_prefix}*",
      "${local.iam_arn_base}:policy/${var.iam_name_prefix}*",
      "${local.iam_arn_base}:instance-profile/${var.iam_name_prefix}*",
    ]
  }

  # EN: Guardrail — even on prefixed roles, never attach admin-level policies.
  #     Without this, the role could create "tf-x" with AdministratorAccess
  #     and escalate its own privileges.
  # FR: Garde-fou — même sur les rôles préfixés, ne jamais attacher de politiques
  #     de niveau administrateur. Sans cela, le rôle pourrait créer « tf-x »
  #     avec AdministratorAccess et élever ses propres privilèges.
  statement {
    sid       = "DenyAdminPolicyAttachment"
    effect    = "Deny"
    actions   = ["iam:AttachRolePolicy"]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values = [
        "arn:${local.partition}:iam::aws:policy/AdministratorAccess",
        "arn:${local.partition}:iam::aws:policy/IAMFullAccess",
      ]
    }
  }
}

resource "aws_iam_policy" "scoped_iam" {
  name        = "${var.iam_name_prefix}terraform-scoped-iam"
  description = "Scoped IAM permissions for the Terraform course role"
  policy      = data.aws_iam_policy_document.scoped_iam.json
}

resource "aws_iam_role_policy_attachment" "scoped_iam" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.scoped_iam.arn
}
