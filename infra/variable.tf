variable "identifier" {
  type        = string
  description = "The name of the AWS RDS instance"
  default     = "rds-demo"
}

variable "db_identifier" {
  type        = string
  description = "The database instance identifier"
  default     = "mydb"
}

variable "allocated_storage" {
  type        = number
  description = "The allocated storage in gigabytes"
  default     = 10
}

variable "db_name" {
  type        = string
  description = "The name of the database"
  default     = "mydb"
}

variable "engine" {
  type        = string
  description = "The database engine to use"
  default     = "postgres"
}

variable "engine_version" {
  type        = string
  description = "The database engine version"
  default     = "16.13"
}

variable "instance_class" {
  type        = string
  description = "The database instance class"
  default     = "db.t3.micro"
}

variable "db_username" {
  type        = string
  description = "The master username for the database"
  default     = "postgres"
}

variable "db_password_wo_version" {
  type        = number
  description = "Increment to rotate the RDS master password and SSM database_url (ephemeral write-only)."
  default     = 1
}

variable "public_accessible" {
  type        = bool
  description = "Whether the RDS instance should be publicly accessible"
  default     = false
}

variable "worker_image_tag" {
  type        = string
  description = "Immutable ECR tag for the worker image"
  default     = "worker-sqs-auth-fix-20260329"
}

variable "api_image_tag" {
  type        = string
  description = "Immutable ECR tag for the API image"
  default     = "api-sqs-event-fix-20260329"
}

#hosted zone id
variable "hosted_zone_id" {
  type        = string
  description = "The ID of the hosted zone"
  default     = "Z030173428PFHIJ7AINAQ"
}

variable "terraform_state_bucket_name" {
  type        = string
  description = "S3 bucket used by the Terraform remote backend (infra/state.tf)."
}

variable "terraform_state_access_role_arns" {
  type        = list(string)
  description = "IAM role ARNs allowed to read/write Terraform state (e.g. GitHub Actions OIDC deploy role)."
  default     = []
}

variable "terraform_state_enforce_allowlist" {
  type        = bool
  description = "When true and terraform_state_access_role_arns is set, deny all other principals on the state bucket."
  default     = false
}

variable "github_repo" {
  type        = string
  description = "Full GitHub repository ID (owner/name) the container-deploy pipeline tracks."
  default     = "cmomodo/url_shortener_ECS"
}

variable "github_branch" {
  type        = string
  description = "Git branch the container-deploy pipeline tracks."
  default     = "securityn"
}
