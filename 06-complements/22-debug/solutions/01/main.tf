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

variable "ports" {
  type    = list(number)
  default = [80, 443, 8080]
}

resource "local_file" "conf" {
  filename = "${path.module}/out/ports.txt"
  content  = join(",", var.ports)
}
