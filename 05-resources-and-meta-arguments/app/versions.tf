terraform {
  required_version = ">= 1.4.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "local" {
  # Default provider instance configuration
}

provider "local" {
  alias = "backup"
}
