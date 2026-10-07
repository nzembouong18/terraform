terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "texte" {
  type = string
}

resource "local_file" "rapport" {
  filename = "${path.root}/out/rapport.txt"
  content  = var.texte
}
