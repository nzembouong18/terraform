# Aucun cluster nécessaire : providers simulés.
mock_provider "kubernetes" {}
mock_provider "helm" {}

run "deploiement_et_service" {
  command = plan

  assert {
    condition     = kubernetes_deployment.web.spec[0].replicas == "2"
    error_message = "2 replicas par défaut."
  }

  assert {
    condition     = kubernetes_service.web.spec[0].type == "ClusterIP"
    error_message = "Le service ne doit pas être exposé hors du cluster."
  }
}

run "replicas_personnalises" {
  command = plan

  variables {
    replicas = 5
  }

  assert {
    condition     = kubernetes_deployment.web.spec[0].replicas == "5"
    error_message = "5 replicas attendus."
  }
}
