resource "random_pet" "db" {
  prefix = var.environment
  length = 2
}

resource "terraform_data" "release" {
  input = "1.0.0"
}
