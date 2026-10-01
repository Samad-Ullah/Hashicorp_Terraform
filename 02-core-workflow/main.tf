resource "random_pet" "app_name" {
  length = 2
}
resource "random_integer" "port" {
  min = 8000
  max = 8999
}
resource "local_file" "app_config" {
  filename = "${path.module}/config/app.env"

  content = <<-EOT
    APP_NAME=${random_pet.app_name.id}
    APP_PORT=${random_integer.port.result}
    ENV=staging
  EOT
}
