variable "projet" {
  description = "Nom du projet (minuscules, chiffres et tirets)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.projet))
    error_message = "Le nom du projet doit faire 3 à 20 caractères : a-z, 0-9 et '-'."
  }
}

variable "environnement" {
  description = "Environnement cible"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "recette", "prod"], var.environnement)
    error_message = "environnement doit valoir dev, recette ou prod."
  }
}

variable "nombre_replicas" {
  description = "Nombre de replicas"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags additionnels"
  type        = map(string)
  default     = {}
}

variable "serveurs" {
  description = "Liste d'objets typés"
  type = list(object({
    nom  = string
    port = number
    tls  = optional(bool, false) # optional() avec défaut : Terraform >= 1.3
  }))
  default = [
    { nom = "web", port = 80 },
    { nom = "api", port = 8443, tls = true },
  ]
}

variable "mot_de_passe" {
  description = "Exemple de valeur sensible"
  type        = string
  sensitive   = true
  default     = "changeme-en-vrai-via-TF_VAR"
}
