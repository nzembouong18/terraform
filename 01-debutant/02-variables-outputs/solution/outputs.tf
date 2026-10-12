output "prefixe" {
  description = "Préfixe de nommage"
  value       = local.prefixe
}

output "urls" {
  description = "URL de chaque serveur"
  value = {
    for nom, s in local.serveurs_par_nom :
    nom => "${s.tls ? "https" : "http"}://${nom}.${local.prefixe}.example.com:${s.port}"
  }
}

output "mot_de_passe" {
  value     = var.mot_de_passe
  sensitive = true # masqué dans la console, MAIS présent en clair dans le state !
}
