variable "environment" {
  type    = string
  default = "dev"
}
variable "owner" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
