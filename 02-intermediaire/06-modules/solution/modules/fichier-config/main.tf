resource "local_file" "this" {
  filename = "${var.repertoire}/${var.nom}.conf"
  content = join("\n", concat(
    ["# application ${var.nom}"],
    [for k, v in var.parametres : "${k}=${v}"],
    [""],
  ))
}
