# Remote state bucket. The S3 backend is configured at init time (e.g. via
# `terraform init -backend-config=...`), not in a tracked file in this stack.
# The bucket itself is created outside this stack; this file only attaches
# least-privilege access controls via a bucket policy.

data "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket_name
}

locals {
  terraform_state_bucket_arn         = data.aws_s3_bucket.terraform_state.arn
  terraform_state_bucket_objects_arn = "${local.terraform_state_bucket_arn}/*"

  terraform_state_enforce_allowlist = var.terraform_state_enforce_allowlist && length(var.terraform_state_access_role_arns) > 0
}

data "aws_iam_policy_document" "terraform_state_bucket" {
  # SEC-3: require TLS for all S3 API calls to the state bucket.
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [local.terraform_state_bucket_arn, local.terraform_state_bucket_objects_arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = length(var.terraform_state_access_role_arns) > 0 ? [1] : []

    content {
      sid    = "AllowTerraformStateAccess"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = var.terraform_state_access_role_arns
      }

      actions = [
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
      ]

      resources = [local.terraform_state_bucket_arn, local.terraform_state_bucket_objects_arn]
    }
  }

  dynamic "statement" {
    for_each = local.terraform_state_enforce_allowlist ? [1] : []

    content {
      sid    = "DenyAccessNotFromAllowedRoles"
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions   = ["s3:*"]
      resources = [local.terraform_state_bucket_arn, local.terraform_state_bucket_objects_arn]

      condition {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = var.terraform_state_access_role_arns
      }
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = data.aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state_bucket.json
}
