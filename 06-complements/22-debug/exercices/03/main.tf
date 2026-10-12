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

resource "random_pet" "noms" {
  count  = 3
  length = 2
}

resource "local_file" "par_nom" {
  for_each = toset(random_pet.noms[*].id) # clés inconnues avant l'apply !
  filename = "${path.module}/out/${each.key}.txt"
  content  = "bonjour ${each.key}"
}
