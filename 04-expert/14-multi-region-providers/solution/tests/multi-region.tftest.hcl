# Tests sans compte AWS : UN provider simulé PAR configuration (défaut + alias "replica").
mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::bucket-source"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/replication"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "aws" {
  alias = "replica"

  # Le provider valide le format des ARN : on en fournit un réaliste
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::bucket-replica"
    }
  }
}

variables {
  prefixe = "test-multi-region"
}

run "buckets_source_et_replica" {
  command = apply

  assert {
    condition     = output.buckets.source == "test-multi-region-source"
    error_message = "Nom du bucket source inattendu."
  }

  assert {
    condition     = output.buckets.replica == "test-multi-region-replica"
    error_message = "Nom du bucket réplica inattendu."
  }

  assert {
    condition     = module.donnees.bucket_source != module.donnees.bucket_replica
    error_message = "Les deux buckets doivent être distincts."
  }
}
