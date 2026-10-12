variable "nom" {
  type = string

  validation {
    condition     = length(var.nom) >= 3
    error_message = "Le nom doit faire au moins 3 caractères."
  }
}

variable "repertoire" {
  type    = string
  default = "out"
}

variable "ports" {
  type    = list(number)
  default = [80]
}

locals {
  ports_valides = [for p in var.ports : p if p > 0 && p < 65536]
}

resource "local_file" "conf" {
  filename = "${var.repertoire}/${var.nom}.conf"
  content  = join("\n", [for p in local.ports_valides : "listen ${p};"])
}

output "chemin" {
  value = local_file.conf.filename
}

output "nb_ports" {
  value = length(local.ports_valides)
}
