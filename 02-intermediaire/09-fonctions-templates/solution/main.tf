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
  vpc_cidr = "10.20.0.0/16"
  zones    = ["a", "b", "c"]

  # cidrsubnet(prefix, newbits, netnum) : découpe un réseau
  sous_reseaux = { for i, z in local.zones : z => cidrsubnet(local.vpc_cidr, 8, i) }

  utilisateurs = ["alice", "bob"]
}

resource "local_file" "nginx" {
  filename = "${path.module}/out/nginx.conf"
  content = templatefile("${path.module}/templates/nginx.conf.tftpl", {
    serveur = "app.example.com"
    ports   = [80, 443]
    amonts  = ["10.0.0.11", "10.0.0.12"]
  })
}

resource "local_file" "yaml" {
  filename = "${path.module}/out/config.yaml"
  content = yamlencode({
    app    = { nom = "demo", tags = ["a", "b"] }
    reseau = local.sous_reseaux
  })
}

output "sous_reseaux" {
  value = local.sous_reseaux
}

output "demo_fonctions" {
  value = {
    majuscule  = upper("terraform")
    jointure   = join("-", ["a", "b", "c"])
    fusion     = merge({ a = 1 }, { b = 2 })
    recherche  = lookup({ a = 1 }, "z", 0)
    try_       = try(local.sous_reseaux["z"], "absent")
    format_    = format("%s-%03d", "srv", 7)
    regex_     = regex("[0-9]+", "build-1234")
    json       = jsondecode("{\"x\": [1,2,3]}")
    sha        = substr(sha256("terraform"), 0, 12)
    longueur   = length(local.utilisateurs)
    aplati     = flatten([[1, 2], [3]])
    distinct_  = distinct(["a", "a", "b"])
    cidr_hosts = cidrhost("10.20.1.0/24", 10)
  }
}
