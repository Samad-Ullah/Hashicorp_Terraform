# Generates a random pet name to act as a dynamic database host prefix
resource "random_pet" "database" {
  length = 2
}

# Generates configuration files for both "web" and "api" services
resource "local_file" "service" {
  for_each = toset(["web", "api"])

  filename = "${path.module}/out/${terraform.workspace}/${each.key}.env"

  content = <<EOT
SERVICE=${each.key}
DB_HOST=${random_pet.database.id}.db.internal
EOT
}


removed {
  from = time_sleep.deploy

  lifecycle {
    destroy = false
  }
}

resource "consul_key_prefix" "legacy" {
  count       = terraform.workspace == "default" ? 1 : 0
  datacenter  = "dc1"
  path_prefix = "shopcart/legacy/"
  subkeys = {
    db_host = "db1.internal"
    db_port = "5432"
  }
}


moved {
  from = consul_key_prefix.legacy
  to   = consul_key_prefix.legacy[0]
}

