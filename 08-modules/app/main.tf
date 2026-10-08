module "service" {
  source   = "git::https://github.com/Samad-Ullah/Hashicorp_Terraform.git//08-modules/modules/service_config?ref=service-config-v1.0.0"
  for_each = var.services

  name    = each.key
  port    = each.value
  db_host = "db.shopcart.internal"
}

module "index_generator" {
  source = "../modules/service_index"

  # Pass the list of URLs collected from your other services module
  urls = [
    for name, svc in module.service : svc.url
  ]
}


module "templates" {
  source  = "hashicorp/dir/template"
  version = "~> 1.0"

  base_dir = "${path.module}/templates"
  template_vars = {
    app      = "shopcart"
    env      = "dev"
    services = join(", ", keys(var.services))
  }
}

resource "local_file" "rendered" {
  for_each = module.templates.files

  filename = "${path.root}/out/rendered/${each.key}"
  content  = each.value.content
}

moved {
  from = local_file.service_index
  to   = module.index_generator.local_file.this
}
