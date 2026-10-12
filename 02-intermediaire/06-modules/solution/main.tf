terraform {
  required_version = ">= 1.6.0"
}

# Appel simple
module "web" {
  source     = "./modules/fichier-config"
  nom        = "web"
  repertoire = "${path.module}/out"
  parametres = { port = "80", workers = "4" }
}

# Réutilisation avec for_each sur un module (TF >= 0.13)
module "services" {
  source   = "./modules/fichier-config"
  for_each = { api = 8080, auth = 9090, billing = 7070 }

  nom        = each.key
  repertoire = "${path.module}/out"
  parametres = { port = tostring(each.value) }
}

# Source distante (non exécutée ici - exemples de syntaxe) :
#   source  = "terraform-aws-modules/vpc/aws"   # registry public
#   version = "~> 5.0"
#   source  = "git::https://github.com/org/repo.git//modules/vpc?ref=v1.2.0"

output "chemins" {
  value = merge(
    { web = module.web.chemin },
    { for k, m in module.services : k => m.chemin },
  )
}
