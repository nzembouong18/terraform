terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  backend "local" {
    path = "../etat/application.tfstate"
  }
}

# Lit les OUTPUTS (uniquement) de la stack "socle"
data "terraform_remote_state" "socle" {
  backend = "local"
  config = {
    path = "${path.module}/../etat/socle.tfstate"
  }
}

resource "local_file" "deploiement" {
  filename = "${path.module}/out/deploiement.txt"
  content  = "Déploiement sur le cluster ${data.terraform_remote_state.socle.outputs.nom_cluster}\n"
}
