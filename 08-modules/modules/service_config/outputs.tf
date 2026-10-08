output "file_path" {
  value       = local_file.this.filename
  description = "The absolute or relative path to the generated environment configuration file on the local filesystem."
}

output "url" {
  value       = "http://${var.name}.shopcart.internal:${var.port}"
  description = "Internal URL of the service."
}
