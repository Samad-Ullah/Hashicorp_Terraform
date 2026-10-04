data "terraform_remote_state" "platform" {
  backend = "local"
  config = {
    path = "${path.module}/../producer/terraform.tfstate"
  }
}

resource "local_file" "by_count" {
  count    = length(var.service_list)
  filename = "${path.module}/out/count/${var.service_list[count.index]}.env"
  content  = "SERVICE_NAME=${var.service_list[count.index]}\n"
}

resource "local_file" "by_each" {
  for_each = var.service_ports
  filename = "${path.module}/out/each/${each.key}.env"
  content  = <<EOT
PORT=${each.value}
DB_HOST=${data.terraform_remote_state.platform.outputs.db_host}
EOT
}

resource "local_file" "manifest" {
  filename = "${path.module}/out/manifest.txt"
  content  = join("\n", var.service_list)
}

data "local_file" "manifest_check" {
  filename   = "${path.module}/out/manifest.txt"
  depends_on = [local_file.manifest]
}

resource "terraform_data" "release" {
  input = var.release_version
}

resource "local_file" "release_notes" {
  filename = "${path.module}/out/release_notes.txt"
  content  = "Static system release documentation content placeholder text block entries."

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.release]
  }
}

resource "local_file" "audit_log" {
  filename = "${path.module}/out/audit.log"
  content  = "Initial system audit records trail tracking initialization sequence logs.\n"

  # FIX #7: prevent_destroy is now explicitly uncommented and active!
  lifecycle {
    prevent_destroy = true
  }
}

resource "local_file" "banner" {
  filename = "${path.module}/out/banner.txt"
  content  = "System Welcome Banner Initial State.\n"

  lifecycle {
    ignore_changes = [content]
  }
}

resource "terraform_data" "notify" {
  input = var.release_version

  provisioner "local-exec" {
    command = "echo Deployed ${self.input} >> ${path.module}/out/deploy.log"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo Destroyed >> ${path.module}/out/deploy.log"
  }

  depends_on = [local_file.manifest]
}

resource "local_file" "backup_asset" {
  provider = local.backup
  filename = "${path.module}/out/backup_identity.txt"
  content  = "Provider explicit instance replication backup placeholder content logs.\n"
}
