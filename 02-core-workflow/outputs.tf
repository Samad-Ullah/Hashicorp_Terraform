output "app_name" {
  description = "Generated application name"
  value       = random_pet.app_name.id
}

output "app_port" {
  description = "Generated application port"
  value       = random_integer.port.result
}

output "config_path" {
  description = "Path to the generated application configuration file"
  value       = local_file.app_config.filename
}

