terraform {
  required_version = ">= 99.0.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 9.9"
    }
  }
}

resource "random_pet" "x" {}
