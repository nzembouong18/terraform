# Tests SANS credentials AWS : le provider est simulé.
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  nom = "bucket-de-test"
}

run "securite_par_defaut" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy == true
    error_message = "Le blocage d'accès public doit être actif."
  }

  assert {
    condition     = contains(flatten([for r in aws_s3_bucket_server_side_encryption_configuration.this.rule : [for a in r.apply_server_side_encryption_by_default : a.sse_algorithm]]), "AES256")
    error_message = "Chiffrement AES256 attendu par défaut."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.versions) == 1
    error_message = "La règle de lifecycle doit exister par défaut."
  }
}

run "sans_versioning_pas_de_lifecycle" {
  command = plan

  variables {
    versioning = false
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.versions) == 0
    error_message = "Pas de lifecycle sans versioning."
  }
}

run "kms_si_fourni" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:eu-west-3:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = contains(flatten([for r in aws_s3_bucket_server_side_encryption_configuration.this.rule : [for a in r.apply_server_side_encryption_by_default : a.sse_algorithm]]), "aws:kms")
    error_message = "SSE-KMS attendu."
  }
}

run "nom_invalide_refuse" {
  command = plan

  variables {
    nom = "MAJUSCULES_INTERDITES"
  }

  expect_failures = [var.nom]
}
