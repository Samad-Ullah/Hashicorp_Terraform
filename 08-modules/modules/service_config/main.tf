resource "local_file" "this" {
  # Forces the file to be written to the execution project's root out/ folder
  filename = "${path.root}/out/${var.environment}/${var.name}.env"

  content = <<EOT
SERVICE=${var.name}
ENV=${var.environment}
PORT=${var.port}
DB_HOST=${var.db_host}
EOT
}
