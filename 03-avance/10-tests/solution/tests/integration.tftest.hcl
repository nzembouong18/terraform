# Test "apply" : crée réellement les ressources (dans un dossier temporaire),
# puis les détruit automatiquement à la fin du fichier.
variables {
  nom        = "integration"
  repertoire = "out-test"
}

run "creation" {
  command = apply

  assert {
    condition     = fileexists(local_file.conf.filename)
    error_message = "Le fichier doit exister après apply."
  }

  assert {
    condition     = strcontains(local_file.conf.content, "listen 80;")
    error_message = "Le contenu doit déclarer le port 80."
  }
}

run "mise_a_jour" {
  command = apply

  variables {
    ports = [80, 8080]
  }

  assert {
    condition     = output.nb_ports == 2
    error_message = "Deux ports attendus."
  }
}
