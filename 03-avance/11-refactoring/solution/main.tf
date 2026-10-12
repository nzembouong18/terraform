terraform {
  required_version = ">= 1.7.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# --- 1. moved : renommer une ressource
moved {
  from = random_pet.a
  to   = random_pet.principal
}

resource "random_pet" "principal" {
  length = 2
}

# --- 2. moved : déplacer une ressource DANS un module
moved {
  from = local_file.rapport
  to   = module.rapports.local_file.rapport
}

module "rapports" {
  source = "./modules/rapports"
  texte  = random_pet.principal.id
}

# --- 3. import déclaratif (TF >= 1.5) : adopter une ressource existante.
# random_id supporte l'import par son id (base64url). Décommentez pour tester
# après `terraform apply` d'un random_id créé à la main, voir README.
#
# import {
#   to = random_id.adopte
#   id = "dGVzdA"
# }
# resource "random_id" "adopte" {
#   byte_length = 4
# }

# --- 4. removed : sortir du state sans détruire
# removed {
#   from = random_pet.principal
#   lifecycle { destroy = false }
# }
