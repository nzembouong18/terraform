terraform {
  required_version = ">= 1.7.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend distant GCS (à activer en équipe) :
  # backend "gcs" {
  #   bucket = "mon-entreprise-tfstate"
  #   prefix = "formation/dev"
  # }
}

variable "projet_gcp" {
  type        = string
  description = "ID du projet GCP"
  default     = "mon-projet-formation"
}

variable "region" {
  type    = string
  default = "europe-west9"
}

variable "sous_reseaux" {
  type = map(string)
  default = {
    web  = "10.40.1.0/24"
    data = "10.40.2.0/24"
  }
}

provider "google" {
  project = var.projet_gcp
  region  = var.region

  default_labels = {
    gere_par = "terraform"
    projet   = "formation"
  }
}

# Active les APIs nécessaires (disable_on_destroy=false : on ne coupe pas l'API à la destruction)
resource "google_project_service" "api" {
  for_each           = toset(["compute.googleapis.com", "storage.googleapis.com", "iam.googleapis.com"])
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "vpc-formation"
  auto_create_subnetworks = false # on maîtrise l'adressage
  depends_on              = [google_project_service.api]
}

resource "google_compute_subnetwork" "this" {
  for_each                 = var.sous_reseaux
  name                     = "subnet-${each.key}"
  ip_cidr_range            = each.value
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "http" {
  name    = "autoriser-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_firewall" "iap_ssh" {
  name    = "autoriser-ssh-iap"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Plage Identity-Aware Proxy : SSH sans IP publique
  source_ranges = ["35.235.240.0/20"]
}

resource "google_service_account" "app" {
  account_id   = "sa-app-formation"
  display_name = "Compte de service de l'application"
  depends_on   = [google_project_service.api]
}

resource "random_id" "suffixe" {
  byte_length = 3
}

resource "google_storage_bucket" "donnees" {
  name                        = "formation-donnees-${random_id.suffixe.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "app_lecture" {
  bucket = google_storage_bucket.donnees.name
  role   = "roles/storage.objectViewer" # moindre privilège : lecture seule
  member = "serviceAccount:${google_service_account.app.email}"
}

output "reseau" {
  value = google_compute_network.vpc.name
}

output "bucket" {
  value = google_storage_bucket.donnees.name
}

output "service_account" {
  value = google_service_account.app.email
}
