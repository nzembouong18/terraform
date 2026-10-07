terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "taille_mot_de_passe" {
  type    = number
  default = 16
}

# 1. Dépendance implicite : référence à une autre ressource
resource "random_password" "db" {
  length  = var.taille_mot_de_passe
  special = false
}

resource "local_sensitive_file" "db_conf" {
  filename = "${path.module}/out/db.conf"
  content  = "password=${random_password.db.result}\n"

  # 2. Lifecycle : empêcher la destruction accidentelle
  lifecycle {
    prevent_destroy = false # passez à true pour tester l'erreur
  }
}

# 3. Dépendance explicite : depends_on (quand aucune référence n'existe)
resource "local_file" "readme" {
  filename   = "${path.module}/out/README.txt"
  content    = "Fichier de config DB présent dans ce dossier.\n"
  depends_on = [local_sensitive_file.db_conf]
}

# 4. Data source : LIRE un élément existant, sans le gérer
data "local_file" "readme_lu" {
  filename   = local_file.readme.filename
  depends_on = [local_file.readme]
}

# 5. ignore_changes : tolérer une modification faite hors Terraform
resource "local_file" "tolere" {
  filename = "${path.module}/out/tolere.txt"
  content  = "valeur initiale\n"

  lifecycle {
    ignore_changes = [content]
  }
}

# 6. precondition / postcondition (Terraform >= 1.2)
resource "local_file" "valide" {
  filename = "${path.module}/out/valide.txt"
  content  = "longueur du mot de passe : ${var.taille_mot_de_passe}\n"

  lifecycle {
    precondition {
      condition     = var.taille_mot_de_passe >= 12
      error_message = "Un mot de passe de moins de 12 caractères est interdit."
    }
    postcondition {
      condition     = self.content_md5 != ""
      error_message = "Le fichier doit avoir un contenu."
    }
  }
}

# 7. replace_triggered_by : forcer le remplacement quand une autre ressource change
resource "local_file" "derive" {
  filename = "${path.module}/out/derive.txt"
  content  = "dérivé du mot de passe\n"

  lifecycle {
    replace_triggered_by = [random_password.db]
  }
}

output "contenu_readme" {
  value = data.local_file.readme_lu.content
}
