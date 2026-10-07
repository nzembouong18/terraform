terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "equipes" {
  type = map(object({
    membres = list(string)
    actif   = optional(bool, true)
  }))
  default = {
    plateforme = { membres = ["alice", "bob"] }
    data       = { membres = ["chloe"] }
    legacy     = { membres = ["denis"], actif = false }
  }
}

variable "creer_rapport" {
  type    = bool
  default = true
}

variable "ports_ouverts" {
  type    = list(number)
  default = [80, 443, 8080]
}

# --- count : N copies identiques, indexées par position (fragile si on retire un élément au milieu)
resource "local_file" "numerote" {
  count    = 3
  filename = "${path.module}/out/numerote-${count.index}.txt"
  content  = "Fichier n°${count.index}\n"
}

# --- count comme "if" : 0 ou 1 ressource
resource "local_file" "rapport" {
  count    = var.creer_rapport ? 1 : 0
  filename = "${path.module}/out/rapport.txt"
  content  = "Rapport généré\n"
}

# --- for_each : une instance par clé (stable, recommandé)
locals {
  equipes_actives = { for nom, e in var.equipes : nom => e if e.actif }
}

resource "local_file" "equipe" {
  for_each = local.equipes_actives # map -> each.key / each.value
  filename = "${path.module}/out/equipe-${each.key}.txt"
  content  = join("\n", [for m in each.value.membres : upper(m)])
}

# --- for_each sur un set (toset) : convertit une liste en ensemble
resource "local_file" "port" {
  for_each = toset([for p in var.ports_ouverts : tostring(p)])
  filename = "${path.module}/out/port-${each.key}.txt"
  content  = "port ${each.key} ouvert\n"
}

# --- dynamic block : voir le README (exemple aws_security_group) ; local_file n'a pas de bloc imbriqué.
output "tous_les_membres" {
  value = flatten([for e in var.equipes : e.membres])
}

output "chemins_equipes" {
  # for_each => map d'instances ; splat/for pour extraire un attribut
  value = { for k, f in local_file.equipe : k => f.filename }
}

output "chemins_numerotes" {
  value = local_file.numerote[*].filename # splat expression
}

output "rapport_cree" {
  value = length(local_file.rapport) > 0
}

output "membres_par_equipe_taille" {
  value = { for nom, e in var.equipes : nom => length(e.membres) }
}
