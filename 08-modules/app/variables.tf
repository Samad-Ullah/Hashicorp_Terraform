variable "services" {
  type = map(number)
  default = {
    web    = 8080,
    api    = 8081,
    worker = 9000
  }
  description = "Services name mentioned in root"
}
