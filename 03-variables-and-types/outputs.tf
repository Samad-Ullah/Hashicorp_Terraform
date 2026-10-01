output "name_prefix" {
  description = "Application name prefix"
  value       = local.name_prefix
}

output "common_tags" {
  description = "Common tags for the application"
  value       = local.common_tags
}

output "database" {
  description = "Database configuration"
  value       = var.database
}

output "db_password" {
  description = "Database password"
  value       = var.db_password
  sensitive   = true
}

output "availability_zones" {
  description = "Availability zones"
  value       = var.availability_zones
}
