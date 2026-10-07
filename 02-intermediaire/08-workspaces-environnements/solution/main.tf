terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "environnement" {
  type    = string
  default = null # null => on déduit du workspace
}

locals {
  env = coalesce(var.environnement, terraform.workspace)

  # Configuration par environnement (pattern "map de configs")
  config = {
    default = { replicas = 1, taille = "small" }
    dev     = { replicas = 1, taille = "small" }
    prod    = { replicas = 3, taille = "large" }
  }

  courante = local.config[local.env]
}

resource "local_file" "env" {
  filename = "${path.module}/out/${local.env}.txt"
  content  = "env=${local.env} replicas=${local.courante.replicas} taille=${local.courante.taille}\n"
}

output "workspace" {
  value = terraform.workspace
}

output "config" {
  value = local.courante
}
