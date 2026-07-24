variable "bucket_name" {
  type        = string
  description = "S3 bucket used by the Terraform remote backend"
}

variable "access_role_arns" {
  type        = list(string)
  description = "IAM role ARNs allowed to read/write Terraform state (e.g. GitHub Actions OIDC deploy role)"
}

variable "enforce_allowlist" {
  type        = bool
  description = "When true and access_role_arns is set, deny all other principals on the state bucket"
}
