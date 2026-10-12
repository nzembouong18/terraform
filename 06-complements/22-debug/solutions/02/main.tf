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

# Le cycle est cassé : b ne dépend plus de a (une seule direction de dépendance)
resource "local_file" "a" {
  filename = "${path.module}/out/a.txt"
  content  = "b vaut ${local_file.b.content_md5}"
}

resource "local_file" "b" {
  filename = "${path.module}/out/b.txt"
  content  = "contenu indépendant"
}
