output "config_path" {
  value       = { for name, svc in module.service : name => svc.file_path }
  description = "Module path"
}
