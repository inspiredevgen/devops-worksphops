# =============================================================================
# ssm mode only: no SSH at all. Ansible talks to the hosts through AWS Systems Manager.
# Mode ssm seulement : aucun SSH. Ansible parle aux hôtes via AWS Systems Manager.
#   • instance role  tf-ans-ssm-instance  (lets the SSM agent register / permet à l'agent SSM de s'enregistrer)
#   • transfer bucket (the plugin moves files through S3 / le plugin transfère les fichiers via S3)
#   • operator role  tf-ans-operator     (what YOU assume to run Ansible: least privilege / ce que VOUS assumez : moindre privilège)
# EN: IAM names start with tf- so the Terraform course's lab role may create them.
# FR : Les noms IAM commencent par tf- pour que le rôle de lab du cours Terraform puisse les créer.
# =============================================================================

locals {
  ssm_count = local.ssm ? 1 : 0
}

resource "aws_iam_role" "ssm_instance" {
  count = local.ssm_count

  name = "tf-ans-ssm-instance-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = local.ssm_count

  role       = aws_iam_role.ssm_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  count = local.ssm_count

  name = "tf-ans-ssm-instance-${random_id.suffix.hex}"
  role = aws_iam_role.ssm_instance[0].name
}

# EN: The aws_ssm connection plugin uploads/downloads files through this bucket (presigned URLs).
# FR : Le plugin de connexion aws_ssm transfère les fichiers via ce compartiment (URL présignées).
resource "aws_s3_bucket" "ssm" {
  count = local.ssm_count

  bucket        = "ans-lab-ssm-${data.aws_caller_identity.current.account_id}-${random_id.suffix.hex}"
  force_destroy = true # EN: transfer scratch space only / FR : espace de transfert temporaire seulement
}

resource "aws_s3_bucket_public_access_block" "ssm" {
  count = local.ssm_count

  bucket                  = aws_s3_bucket.ssm[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "ssm" {
  count = local.ssm_count

  bucket = aws_s3_bucket.ssm[0].id

  rule {
    id     = "expire-transfers"
    status = "Enabled"
    filter {}
    expiration {
      days = 1
    }
  }
}

# EN: The operator: describe instances, start sessions ONLY on this course's instances, use the bucket.
# FR : L'opérateur : décrire les instances, ouvrir des sessions SEULEMENT sur les instances du cours, utiliser le compartiment.
resource "aws_iam_role" "operator" {
  count = local.ssm_count

  name        = "tf-ans-operator-${random_id.suffix.hex}"
  description = "Runs Ansible over SSM against the course's lab hosts only"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "operator" {
  count = local.ssm_count

  name = "ansible-over-ssm"
  role = aws_iam_role.operator[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Discover"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeTags", "ssm:DescribeInstanceInformation", "ssm:GetConnectionStatus"]
        Resource = "*"
      },
      {
        Sid       = "SessionsOnCourseInstancesOnly"
        Effect    = "Allow"
        Action    = "ssm:StartSession"
        Resource  = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = { StringEquals = { "aws:ResourceTag/Course" = "ansible-cloud-engineer" } }
      },
      {
        Sid    = "SessionDocuments"
        Effect = "Allow"
        Action = "ssm:StartSession"
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/SSM-SessionManagerRunShell",
          "arn:aws:ssm:${var.aws_region}::document/AWS-StartInteractiveCommand",
        ]
      },
      {
        Sid      = "OwnSessions"
        Effect   = "Allow"
        Action   = ["ssm:TerminateSession", "ssm:ResumeSession"]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:session/*"
      },
      {
        Sid      = "TransferBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [aws_s3_bucket.ssm[0].arn, "${aws_s3_bucket.ssm[0].arn}/*"]
      },
    ]
  })
}
