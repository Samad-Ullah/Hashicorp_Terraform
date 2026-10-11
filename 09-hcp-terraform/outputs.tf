output "db_host" {
  value       = "${random_pet.db.id}.db.internal"
  description = "The fully qualified domain name generated for the internal database host."
}

output "release" {
  value       = terraform_data.release.output
  description = "The exact software release version stored within the tracking state resource."
}

output "owner" {
  value       = var.owner
  description = "Owner's name"
}
