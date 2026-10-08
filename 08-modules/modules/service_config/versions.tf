terraform {
  required_version = "~> 1.12"

  required_providers {
    local = {
      version = "~> 2.5"
      source  = "hashicorp/local"
    }
  }
}
