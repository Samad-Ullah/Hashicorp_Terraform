variable "service_list" {
  type        = list(string)
  description = "An array collection listing core service identifiers."
  default     = ["web", "api", "worker"]
}

variable "service_ports" {
  type        = map(number)
  description = "A structural mapping of service names directly to network listening channels."
  default = {
    web    = 8080
    api    = 8081
    worker = 9000
  }
}

variable "release_version" {
  type        = string
  description = "Target execution layer release identifier tag."
  default     = "1.0.0"
}
