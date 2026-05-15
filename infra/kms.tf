#checkov:skip=CKV_AWS_111: KMS key policy requires broad write access for root + services (temporary env)
#checkov:skip=CKV_AWS_356: KMS key policy requires "*" resource for root account and service principals
#checkov:skip=CKV_AWS_109: KMS key policy intentionally allows broad permissions for encryption services
resource "aws_kms_key" "app" {
  description             = "CMK for SSM parameters, CloudWatch Logs, and SQS"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_key_policy.json
}

resource "aws_kms_alias" "app" {
  name          = "alias/url-shortener-app"
  target_key_id = aws_kms_key.app.key_id
}
