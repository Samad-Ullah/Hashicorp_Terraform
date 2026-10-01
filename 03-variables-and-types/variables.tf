variable "environment" {
  description = "Deployment environment name"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "shopcart"
}

variable "replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 1
}

variable "enable_debug" {
  description = "Whether debug mode is enabled"
  type        = bool
  default     = false
}

variable "allowed_ips" {
  description = "List of allowed IP addresses"
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "Set of availability zones"
  type        = set(string)
  default     = ["a", "b"]
}

variable "feature_flags" {
  description = "Map of feature flags"
  type        = map(bool)
  default     = {}
}

variable "maintenance_window" {
  description = "Maintenance window as day and hour"
  type        = tuple([string, number])
  default     = ["sun", 3]
}

variable "database" {
  description = "Database configuration"
  type = object({
    engine  = string
    version = string
    port    = optional(number, 5432)
    backups = optional(bool, false)
  })
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
