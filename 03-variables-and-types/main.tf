resource "local_file" "app_config" {
  filename = "${path.module}/config/${var.environment}.env"

  content = <<-EOT
    NAME_PREFIX=${local.name_prefix}
    REPLICAS=${var.replicas}
    DEBUG=${var.enable_debug}
    ALLOWED_IPS=${join(",", var.allowed_ips)}
    MAINTENANCE_DAY=${var.maintenance_window[0]}
    MAINTENANCE_HOUR=${var.maintenance_window[1]}
  EOT
}

resource "local_file" "database_config" {
  filename = "${path.module}/config/${var.environment}-db.json"

  content = jsonencode(var.database)
}

resource "local_sensitive_file" "db_secret" {
  filename = "${path.module}/config/${var.environment}-secret.env"

  content = "DB_PASSWORD=${var.db_password}\n"
}
