# =============================================================================
# Lab 10.I-AWS — SOLUTION: every finding fixed, or accepted with a written justification
# Lab 10.I-AWS — SOLUTION : chaque constat corrigé, ou accepté avec une justification écrite
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name = "tf-lab-m10-secure"
  tags = {
    Course    = "terraform-cloud-engineer"
    Module    = "10-security"
    ManagedBy = "terraform"
    Owner     = var.owner
  }
}

# ------------------------------------------------------------ KMS (customer-managed key)
data "aws_iam_policy_document" "kms" {
  # EN: In a KEY policy, "*" means "this key", not "every resource": a known scanner false positive.
  # FR : Dans une politique de CLÉ, « * » signifie « cette clé », pas « toutes les ressources » : faux positif connu.
  #checkov:skip=CKV_AWS_111:Key policy; "*" refers to this key only.
  #checkov:skip=CKV_AWS_356:Key policy; "*" refers to this key only.
  #checkov:skip=CKV_AWS_109:Key policy; the account root must administer its own key.
  # EN: The account keeps full control of its key (required, or the key becomes unmanageable).
  # FR : Le compte garde le contrôle total de sa clé (obligatoire, sinon la clé devient ingérable).
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # EN: CloudWatch Logs may use the key, only for this account's log groups.
  # FR : CloudWatch Logs peut utiliser la clé, seulement pour les groupes de journaux de ce compte.
  statement {
    sid       = "CloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "${local.name} data key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.this.key_id
}

# ------------------------------------------------------------ S3: private, versioned, CMK-encrypted
# EN: Trivy reads ignore comments on the line ABOVE the block; Checkov reads skips INSIDE it.
# FR : Trivy lit les commentaires d'exclusion sur la ligne AU-DESSUS du bloc ; Checkov lit les exclusions À L'INTÉRIEUR.
#trivy:ignore:AWS-0089
resource "aws_s3_bucket" "data" {
  # EN: Accepted risks, documented where they live:
  # FR : Risques acceptés, documentés là où ils se trouvent :
  #checkov:skip=CKV_AWS_144:Single-region lab data; cross-region replication is out of scope (see Module 8 for DR).
  #checkov:skip=CKV2_AWS_62:No consumer for event notifications in this lab.
  #checkov:skip=CKV_AWS_18:Access logging needs a dedicated log bucket; covered by CloudTrail data events in production.
  bucket = "${local.name}-data-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    object_ownership = "BucketOwnerEnforced" # EN: ACLs disabled / FR : ACL désactivées
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "hygiene"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.data]
}

# ------------------------------------------------------------ Network: no SSH, narrow egress
resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "App: HTTPS in from the internal network only, HTTPS out only"
}

resource "aws_vpc_security_group_ingress_rule" "https_in" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS from the internal network"
  cidr_ipv4         = var.app_ingress_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "https_out" {
  #checkov:skip=CKV_AWS_382:Not all ports: HTTPS only, needed for AWS APIs and package repositories.
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to AWS APIs and package repositories"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# ------------------------------------------------------------ IAM: least privilege + SSM instead of SSH
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name}-app"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

# EN: Session Manager replaces SSH: no port 22, no keys, every session logged.
# FR : Session Manager remplace SSH : pas de port 22, pas de clés, chaque session journalisée.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "ReadAppData"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.data.arn}/*"]
  }

  statement {
    sid       = "DecryptAppData"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.this.arn]
  }
}

resource "aws_iam_policy" "app" {
  name   = "${local.name}-app"
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app.arn
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-app"
  role = aws_iam_role.app.name
}

# ------------------------------------------------------------ Compute: private, hardened, no secrets
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  associate_public_ip_address = false
  monitoring                  = true
  ebs_optimized               = true

  # EN: No secrets here: the app reads them at runtime from Secrets Manager with its IAM role.
  # FR : Aucun secret ici : l'application les lit à l'exécution dans Secrets Manager avec son rôle IAM.
  user_data = <<-EOT
    #!/bin/bash
    echo "starting app"
  EOT

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted   = true
    kms_key_id  = aws_kms_key.this.arn
    volume_type = "gp3"
  }
}

# ------------------------------------------------------------ Logs: retained 1 year, CMK-encrypted
resource "aws_cloudwatch_log_group" "app" {
  name              = "/tf-lab/m10/secure"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.this.arn
}
