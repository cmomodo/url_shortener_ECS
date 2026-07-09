variable "kms_key_id" {
  type        = string
  description = "ID of the CMK used to encrypt the SecureString parameters"
}

variable "db_username" {
  type        = string
  description = "Database master username"
}

variable "db_password" {
  type        = string
  description = "Database master password (ephemeral; only written via value_wo)"
  ephemeral   = true
  sensitive   = true
}

variable "db_endpoint" {
  type        = string
  description = "Database endpoint (host:port)"
}

variable "db_name" {
  type        = string
  description = "Database name"
}

variable "db_password_wo_version" {
  type        = number
  description = "Increment together with the RDS password rotation to push a new database_url"
}

variable "sqs_queue_url" {
  type        = string
  description = "URL of the click-events SQS queue"
}

variable "redis_auth_token" {
  type        = string
  description = "Redis AUTH token"
  sensitive   = true
}

variable "redis_endpoint" {
  type        = string
  description = "Redis primary endpoint address"
}

variable "redis_port" {
  type        = number
  description = "Redis port"
}
