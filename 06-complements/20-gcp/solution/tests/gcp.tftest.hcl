mock_provider "google" {}
mock_provider "random" {}

run "reseau_et_securite" {
  command = plan

  assert {
    condition     = google_compute_network.vpc.auto_create_subnetworks == false
    error_message = "Pas de sous-réseaux automatiques."
  }

  assert {
    condition     = length(google_compute_subnetwork.this) == 2
    error_message = "2 sous-réseaux attendus."
  }

  assert {
    condition     = google_storage_bucket.donnees.public_access_prevention == "enforced"
    error_message = "Accès public interdit sur le bucket."
  }

  assert {
    condition     = google_storage_bucket_iam_member.app_lecture.role == "roles/storage.objectViewer"
    error_message = "Le compte de service doit être en lecture seule."
  }
}
