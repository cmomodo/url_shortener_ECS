# Ephemeral password: not stored in Terraform state or plan files.
# password_wo_version / value_wo_version control when a new value is pushed to AWS.
ephemeral "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ElastiCache auth_token has no write-only attribute; kept sensitive in state.
# AWS ElastiCache AUTH token constraints:
#   - 16–128 printable ASCII characters
#   - Allowed special characters: ! & # $ ^ < > -
#   - Disallowed: / " @ and any special chars not in the allowed list above
resource "random_password" "redis_auth" {
  length           = 32
  special          = true
  override_special = "!&#$^<>-"
}
