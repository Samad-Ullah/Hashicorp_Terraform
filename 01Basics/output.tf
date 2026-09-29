output "file_path" {
  description = "Path of the file created by Terraform"

  value = local_file.hello.filename
}
