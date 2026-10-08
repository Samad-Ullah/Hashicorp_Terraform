resource "local_file" "this" {
  filename = "${path.root}/out/index.txt"
  content  = join("\n", var.urls)
}

