resource "local_file" "nginx_conf" {
  filename = "${path.module}/out/nginx.conf"
  content = templatefile("${path.module}/templates/nginx.conf.tftpl", {
    log_level = local.log_level
    is_prod   = local.is_prod
    services  = [for name in local.public_services : local.services_by_name[name]]
  })
}

resource "local_file" "services_json" {
  filename = "${path.module}/out/services.json"
  content  = jsonencode(local.services_by_name)
}

resource "local_file" "services_yaml" {
  filename = "${path.module}/out/services.yaml"
  content  = yamlencode(local.services_by_name)
}

resource "local_file" "summary" {
  filename = "${path.module}/out/SUMMARY.txt"
  # FIX: Incorporated format() layout rendering
  content = <<EOT
Environment: ${upper(var.environment)} | ${format("%d services", length(var.services))} | public: ${join(", ", local.public_services)}
EOT
}

data "archive_file" "bundle" {
  type        = "zip"
  output_path = "${path.module}/out/shopcart-${var.environment}.zip"

  dynamic "source" {
    for_each = {
      "nginx.conf"    = local_file.nginx_conf.content
      "services.json" = local_file.services_json.content
    }
    content {
      content  = source.value
      filename = source.key
    }
  }
}
