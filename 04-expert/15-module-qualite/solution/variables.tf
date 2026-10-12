variable "nom" {
  description = "Nom du bucket (globalement unique)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{2,62}$", var.nom))
    error_message = "Nom de bucket S3 invalide."
  }
}

variable "versioning" {
  description = "Active le versioning"
  type        = bool
  default     = true
}

variable "retention_jours_versions" {
  description = "Durée de conservation des anciennes versions (0 = illimité)"
  type        = number
  default     = 90

  validation {
    condition     = var.retention_jours_versions >= 0
    error_message = "La rétention ne peut pas être négative."
  }
}

variable "kms_key_arn" {
  description = "Clé KMS ; si null, chiffrement SSE-S3 (AES256)"
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Autorise la suppression d'un bucket non vide (réservé aux environnements jetables)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags appliqués à toutes les ressources"
  type        = map(string)
  default     = {}
}
