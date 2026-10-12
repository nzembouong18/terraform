terraform {
  required_version = ">= 1.6.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# 1. Ne JAMAIS mettre de secret dans le code ni dans un .tfvars versionné.
#    Fournir via : export TF_VAR_api_token=... (ou un coffre : Vault, AWS Secrets Manager, ...)
variable "api_token" {
  description = "Jeton d'API (fourni via TF_VAR_api_token)"
  type        = string
  sensitive   = true
  default     = "valeur-de-demo" # en vrai : pas de default pour un secret

  validation {
    condition     = length(var.api_token) >= 8
    error_message = "Jeton trop court."
  }
}

# 2. Générer plutôt que stocker : le secret n'apparaît jamais dans le dépôt.
resource "random_password" "db" {
  length  = 24
  special = true
}

# 3. sensitive masque l'affichage CLI, PAS le state : protégez le backend
#    (chiffrement, IAM restrictif, versioning, pas de state en clair dans git).
resource "local_sensitive_file" "credentials" {
  filename        = "${path.module}/out/credentials"
  content         = "token=${var.api_token}\ndb=${random_password.db.result}\n"
  file_permission = "0600"
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}

# 4. Pour afficher volontairement une valeur dérivée non sensible :
output "longueur_token" {
  value = nonsensitive(length(var.api_token))
}

# --- Terraform >= 1.10 : valeurs éphémères (jamais écrites dans le state/plan)
# variable "token" { type = string  ephemeral = true }
# ephemeral "random_password" "x" { length = 20 }
# Terraform >= 1.11 : attributs "write-only" (ex. password_wo sur aws_db_instance)
# => voir 03-avance/13-securite/README.md
