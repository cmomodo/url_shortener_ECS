variable "vpc_id" {
  type        = string
  description = "VPC in which the endpoints are created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the interface endpoints"
}

variable "security_group_id" {
  type        = string
  description = "Security group attached to the interface endpoints"
}

variable "private_route_table_id" {
  type        = string
  description = "Route table associated with the S3 gateway endpoint"
}
