module "service" {
  source   = "../modules/service_config"
  for_each = var.services

  name    = each.key
  port    = each.value
  db_host = "db.shopcart.internal"
}

resource "local_file" "service_index" {
  filename = "${path.root}/out/index.txt"

  content = join("\n", [
    for name, svc in module.service : svc.url
  ])
}
