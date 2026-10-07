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

# Ressource "random_pet" : génère un nom aléatoire mais STABLE (stocké dans le state)
resource "random_pet" "serveur" {
  length = 2
}

# Ressource "local_file" : crée un fichier sur votre machine
resource "local_file" "bienvenue" {
  filename = "${path.module}/out/bienvenue.txt"
  content  = "Bonjour depuis ${random_pet.serveur.id} !\n"
}

output "nom_serveur" {
  description = "Nom généré aléatoirement"
  value       = random_pet.serveur.id
}

output "chemin_fichier" {
  value = local_file.bienvenue.filename
}
