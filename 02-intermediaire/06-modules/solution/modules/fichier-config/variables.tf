variable "nom" {
  description = "Nom de l'application"
  type        = string
}

variable "repertoire" {
  description = "Répertoire de sortie"
  type        = string
}

variable "parametres" {
  description = "Paires clé/valeur écrites dans le fichier"
  type        = map(string)
  default     = {}
}
