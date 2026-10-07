terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }

  # Configuration PARTIELLE : valeurs fournies à l'init
  #   terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = "eu-west-3"

  default_tags {
    tags = {
      projet        = "formation"
      environnement = "dev"
      proprietaire  = "equipe-plateforme"
      gere_par      = "terraform"
    }
  }
}

module "reseau" {
  source = "../../modules/reseau"

  nom                = "formation-dev"
  cidr               = "10.10.0.0/16"
  nb_zones           = 2
  nat_gateway_unique = true
}

module "application" {
  source = "../../modules/application"

  nom             = "formation-dev"
  vpc_id          = module.reseau.vpc_id
  subnets_publics = module.reseau.subnets_publics
  subnets_prives  = module.reseau.subnets_prives
  capacite        = { min = 1, max = 2, desired = 1 }
}

output "url" {
  value = module.application.url
}
