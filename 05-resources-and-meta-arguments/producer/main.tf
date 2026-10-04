resource "random_pet" "db" {
  length = 2
}

output "db_host" {
  description = "The fully qualified internal database host reference."
  value       = "${random_pet.db.id}.db.internal"
}
