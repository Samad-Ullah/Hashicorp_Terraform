terraform {
  cloud {
    organization = "samad-shopcart-org"
    workspaces {
      name = "shopcart-legacy"
    }
  }
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

resource "random_pet" "legacy" {}

output "pet" {
  value = random_pet.legacy.id
}


output "greeting" {
  value = "Hello from ${random_pet.legacy.id}!"
}
