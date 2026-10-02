output "service_names" {
  description = "List of all tracked service identifiers."
  value       = local.service_names
}

output "services_by_name" {
  description = "Map mapping service names directly to their full metadata definitions."
  value       = local.services_by_name
}

output "public_services" {
  description = "Filtered collection of public-facing workloads."
  value       = local.public_services
}

output "is_prod" {
  description = "Boolean flag stating whether the module is configured for production environments."
  value       = local.is_prod
}

output "replicas" {
  description = "Evaluated replica thresholds per individual workflow configuration."
  value       = local.replicas
}

output "log_level" {
  description = "The dynamic Nginx server logging severity metric."
  value       = local.log_level
}

output "subnets" {
  description = "Calculated network blocks assigned per unique processing stack item."
  value       = local.subnets
}

output "by_visibility" {
  description = "Services cleanly broken down and grouped by visibility maps."
  value       = local.by_visibility
}

output "bundle_size" {
  description = "The output payload dimension metric of our bundle asset package."
  value       = data.archive_file.bundle.output_size
}
