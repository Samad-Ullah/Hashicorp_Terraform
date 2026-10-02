locals {
  service_names    = var.services[*].name
  services_by_name = { for s in var.services : s.name => s }
  public_services  = [for s in var.services : s.name if s.public]
  is_prod          = var.environment == "prod"
  replicas         = { for s in var.services : s.name => local.is_prod ? max(3, s.replicas) : s.replicas }
  log_level        = local.is_prod ? "warn" : "debug"
  subnets          = { for idx, s in var.services : s.name => cidrsubnet(var.base_cidr, 8, idx) }

  # FIX: Grouping with ellipsis operator (...) based on a visibility conditional key
  by_visibility = { for s in var.services : s.public ? "public" : "private" => s.name... }
}
