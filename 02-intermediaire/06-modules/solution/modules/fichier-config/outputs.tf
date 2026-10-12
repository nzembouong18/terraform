output "chemin" {
  description = "Chemin du fichier généré"
  value       = local_file.this.filename
}

output "empreinte" {
  description = "MD5 du contenu"
  value       = local_file.this.content_md5
}
