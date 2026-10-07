# mock_provider : teste sans toucher au vrai provider (idéal pour AWS/Azure/GCP sans credentials)
mock_provider "local" {}

variables {
  nom = "mock"
}

run "avec_provider_simule" {
  command = apply

  assert {
    condition     = output.nb_ports == 1
    error_message = "Un port par défaut attendu."
  }
}
