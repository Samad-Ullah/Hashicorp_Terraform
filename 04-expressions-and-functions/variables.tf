variable "environment" {
  type        = string
  default     = "dev"
  description = "The target deployment environment (e.g., dev, staging, prod)."
}

variable "base_cidr" {
  type        = string
  default     = "10.20.0.0/16"
  description = "The primary base CIDR block used to carve out subnets."
}

variable "services" {
  type = list(object({
    name     = string
    port     = number
    public   = bool
    replicas = optional(number, 1)
  }))
  description = "The full array of internal service objects defining ports, routing visibility, and scales."
  default = [
    { name = "web", port = 8080, public = true },
    { name = "api", port = 8081, public = true, replicas = 2 },
    { name = "worker", port = 9000, public = false },
    { name = "payments", port = 8443, public = false, replicas = 2 }
  ]
}
