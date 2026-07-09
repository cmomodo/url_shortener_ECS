variable "db_identifier" {
  type        = string
  description = "The database instance identifier"
}

variable "allocated_storage" {
  type        = number
  description = "The allocated storage in gigabytes"
}

variable "db_name" {
  type        = string
  description = "The name of the database"
}

variable "engine" {
  type        = string
  description = "The database engine to use"
}

variable "engine_version" {
  type        = string
  description = "The database engine version"
}

variable "instance_class" {
  type        = string
  description = "The database instance class"
}

variable "db_username" {
  type        = string
  description = "The master username for the database"
}

variable "db_password_wo_version" {
  type        = number
  description = "Increment to rotate the RDS master password (ephemeral write-only)."
}

variable "public_accessible" {
  type        = bool
  description = "Whether the RDS instance should be publicly accessible"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the CMK used for storage and Performance Insights encryption"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs attached to the DB instance"
}
