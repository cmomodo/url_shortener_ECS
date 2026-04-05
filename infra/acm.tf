#importing the current domain.
data "aws_acm_certificate" "cert" {
  domain      = "ceedev.co.uk"
  statuses    = ["ISSUED"]
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}
