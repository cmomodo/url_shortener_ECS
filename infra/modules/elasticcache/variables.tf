variable "replication_group_id" {
  type        = string
  description = "ElastiCache replication group ID"
  default     = "url-shortener-redis"
}

variable "engine" {
  type        = string
  description = "Cache engine"
  default     = "redis"
}

variable "engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.1"
}

variable "node_type" {
  type        = string
  description = "Cache node instance type"
  default     = "cache.t3.micro"
}

variable "port" {
  type        = number
  description = "Redis port"
  default     = 6379
}

variable "subnet_group_name" {
  type        = string
  description = "Subnet group name"
  default     = "url-shortener-cache"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the ElastiCache subnet group"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs attached to the replication group"
}

variable "auth_token" {
  type        = string
  description = "Redis AUTH token (16–128 chars; required when transit encryption is enabled)"
  sensitive   = true
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID or ARN for ElastiCache at-rest encryption"
}

variable "snapshot_window" {
  type        = string
  description = "Daily snapshot window (UTC)"
  default     = "03:00-05:00"
}
