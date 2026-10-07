terraform {
  required_version = ">= 1.6.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend "local" explicite : le state est rangé dans ../etat/socle.tfstate
  # En production on utiliserait S3 (+ verrou), azurerm, gcs ou HCP Terraform.
  backend "local" {
    path = "../etat/socle.tfstate"
  }
}

resource "random_pet" "cluster" {
  length = 2
}

output "nom_cluster" {
  value = random_pet.cluster.id
}
