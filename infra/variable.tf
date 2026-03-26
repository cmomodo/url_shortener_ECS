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
  default     = "mysql"
}

variable "engine_version" {
  type        = string
  description = "The database engine version"
  default     = "8.0"
}

variable "instance_class" {
  type        = string
  description = "The database instance class"
  default     = "db.t3.micro"
}

variable "db_username" {
  type        = string
  description = "The master username for the database"
  default     = "foo"
}

variable "db_password" {
  type        = string
  description = "The master password for the database"
  default     = "foobarbaz"
  sensitive   = true
}

variable "parameter_group_name" {
  type        = string
  description = "The database parameter group name"
  default     = "default.mysql8.0"
}
