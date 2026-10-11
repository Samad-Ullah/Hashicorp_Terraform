terraform {
  required_version = ">= 1.12"

  cloud {
    organization = "samad-shopcart-org"
    workspaces {
      name = "shopcart-dev"
    }
  }

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
