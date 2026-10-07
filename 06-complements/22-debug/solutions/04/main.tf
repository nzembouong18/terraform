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

variable "mot_de_passe" {
  type      = string
  sensitive = true
  default   = "secret-de-demo"
}

# Une valeur dérivée d'un secret reste sensible : on le déclare explicitement
output "mot_de_passe_derive" {
  value     = "pwd-${var.mot_de_passe}"
  sensitive = true
}
