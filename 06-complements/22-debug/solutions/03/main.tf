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

# Clés STATIQUES (connues au plan) ; la valeur aléatoire va dans les attributs
locals {
  indices = toset(["0", "1", "2"])
}

resource "random_pet" "noms" {
  for_each = local.indices
  length   = 2
}

resource "local_file" "par_nom" {
  for_each = local.indices
  filename = "${path.module}/out/pet-${each.key}.txt"
  content  = "bonjour ${random_pet.noms[each.key].id}"
}
