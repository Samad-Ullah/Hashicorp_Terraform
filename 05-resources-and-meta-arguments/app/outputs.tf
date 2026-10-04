output "remote_db_host" {
  description = "The database cluster host pointer recovered via remote state tracking endpoints."
  value       = data.terraform_remote_state.platform.outputs.db_host
}

output "manifest_check_content" {
  description = "The absolute string contents returned through manifest validation tasks."
  value       = data.local_file.manifest_check.content
}

output "count_file_paths" {
  description = "Target list paths compiled via sequential multi-count deployments."
  value       = local_file.by_count[*].filename
}

output "each_file_paths" {
  description = "A collection list array containing our target paths generated using maps."
  value       = [for f in local_file.by_each : f.filename]
}
