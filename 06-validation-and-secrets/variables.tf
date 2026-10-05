variable "environment" {
  type        = string
  default     = "dev"
  description = "The target deployment environment layer"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment value must be one of 'dev', 'staging', or 'prod'."
  }

}

variable "app_name" {
  type        = string
  default     = "shopcart"
  description = "This is the app name being deployed"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "The app_name variable must only contain lowercase letters, numbers, and hyphens."
  }

  validation {
    condition     = length(var.app_name) >= 3 && length(var.app_name) <= 20
    error_message = "The app_name variable must be between 3 and 20 characters long (inclusive)."
  }
}

variable "replicas" {
  type        = number
  default     = 1
  description = "default value of application replicas"

  validation {
    condition     = var.environment != "prod" || var.replicas >= 3
    error_message = "Production environments require at least 3 replicas to ensure high availability."
  }

}
