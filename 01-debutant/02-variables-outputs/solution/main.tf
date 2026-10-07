terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  prefixe = "${var.projet}-${var.environnement}"

  tags_communs = merge(
    {
      projet        = var.projet
      environnement = var.environnement
    },
    var.tags,
  )

  # Transformation d'une liste en map indexée par nom
  serveurs_par_nom = { for s in var.serveurs : s.nom => s }
}

resource "local_file" "inventaire" {
  filename = "${path.module}/out/${local.prefixe}.json"
  content = jsonencode({
    prefixe  = local.prefixe
    replicas = var.nombre_replicas
    tags     = local.tags_communs
    serveurs = local.serveurs_par_nom
  })
}

resource "local_sensitive_file" "secret" {
  filename = "${path.module}/out/${local.prefixe}.secret"
  content  = var.mot_de_passe
}
