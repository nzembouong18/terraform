terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "multi" {
  type    = bool
  default = true
}

locals {
  serveurs = var.multi ? ["a", "b"] : { principal = "a" }
}

resource "local_file" "s" {
  filename = "${path.module}/out/serveurs.txt"
  content  = jsonencode(local.serveurs)
}
