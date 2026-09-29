resource "local_file" "hello" {
  filename = "${path.module}/hello.txt"

  content = "Hello Samad! Welcome to Terraform.and i am learninf terraform"
}
