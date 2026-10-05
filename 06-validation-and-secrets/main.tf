resource "local_file" "app_config" {
  filename = "${path.module}/out/app.env"

  content = <<EOT
APP=${var.app_name}
ENV=${var.environment}
REPLICAS=${var.replicas}
EOT

  lifecycle {
    precondition {
      condition     = var.replicas <= 10
      error_message = "The replica count cannot exceed 10 instances to prevent resource exhausting."
    }
    postcondition {
      condition     = strcontains(self.content, "APP=")
      error_message = "The generated configuration file is invalid because the 'APP=' variable assignment is missing."
    }
  }
}

ephemeral "vault_kv_secret_v2" "db" {
  mount = "secret"
  name  = "shopcart/db"
}

ephemeral "random_password" "reporting" {
  length = 16
}


resource "vault_kv_secret_v2" "reporting" {
  mount = "secret"
  name  = "shopcart/reporting"

  data_json_wo = jsonencode({
    username = ephemeral.vault_kv_secret_v2.db.data["username"]
    password = ephemeral.random_password.reporting.result
  })
  data_json_wo_version = 2
}
