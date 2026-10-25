# Tests rapides : "plan" uniquement, aucune ressource créée.
variables {
  nom = "demo"
}

run "nom_valide_produit_le_bon_chemin" {
  command = plan

  assert {
    condition     = output.chemin == "out/demo.conf"
    error_message = "Chemin inattendu : ${output.chemin}"
  }
}

run "ports_invalides_sont_filtres" {
  command = plan

  variables {
    ports = [80, 0, 70000, 443]
  }

  assert {
    condition     = output.nb_ports == 2
    error_message = "Seuls 80 et 443 doivent être conservés."
  }
}

run "nom_trop_court_est_rejete" {
  command = plan

  variables {
    nom = "ab"
  }

  expect_failures = [var.nom]
}

# Les valeurs internes (locals) sont accessibles dans les assertions
run "locals_accessibles" {
  command = plan

  variables {
    ports = [22, 80, 99999]
  }

  assert {
    condition     = length(local.ports_valides) == 2 && !contains(local.ports_valides, 99999)
    error_message = "Les ports hors plage doivent être éliminés dans local.ports_valides."
  }
}
