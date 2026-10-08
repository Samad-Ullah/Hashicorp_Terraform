variable "name" {
  type        = string
  description = "It is name getting from parent module"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "If env is dev is default otherwise it came from parent module"
}

variable "port" {
  type        = number
  description = "It is port getting from parent module"

  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "The port number must be a non-privileged port between 1024 and 65535 (inclusive)."
  }
}

variable "db_host" {
  type        = string
  description = "It is description getting from parent module"
}
