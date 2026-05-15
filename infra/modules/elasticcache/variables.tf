#cluster_id for the elasticache cluster
variable "cluster_id" {
  type        = string
  description = "Cluster ID for the elasticache cluster"
  default     = "cluster-url"
}

#engine for the elasticache cluster
variable "engine" {
  type        = string
  description = "Engine for the elasticache cluster"
  default     = "redis"
}

#engine_version for the elasticache cluster
variable "engine_version" {
  type        = string
  description = "Engine version for the elasticache cluster"
  default     = "7.1"
}

#node_type for the elasticache cluster  
variable "node_type" {
  type        = string
  description = "Node type for the elasticache cluster"
  default     = "cache.t3.micro"
}

#num_cache_nodes for the elasticache cluster
variable "num_cache_nodes" {
  type        = number
  description = "Number of cache nodes for the elasticache cluster"
  default     = 1
}

#parameter_group_name for the elasticache cluster
variable "parameter_group_name" {
  type        = string
  description = "Parameter group name for the elasticache cluster"
  default     = "default.redis7"
}

#port for the elasticache cluster
variable "port" {
  type        = number
  description = "Port for the elasticache cluster"
  default     = 6379
}

#subnet_group_name for the elasticache cluster
variable "subnet_group_name" {
  type        = string
  description = "Subnet group name for the elasticache cluster"
  default     = "url-shortener-cache"
}

#private subnet ids for the elasticache subnet group
variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the elasticache subnet group"
}

#security_group_ids for the elasticache cluster
variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for the elasticache cluster"
}

#windows for the elasticache cluster
variable "snapshot_window" {
  type        = string
  description = "Snapshot window for the elasticache cluster"
  default     = "03:00-05:00"
}