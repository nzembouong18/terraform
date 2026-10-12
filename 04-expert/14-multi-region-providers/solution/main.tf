terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }
}

variable "region_principale" {
  type    = string
  default = "eu-west-3"
}

variable "region_replica" {
  type    = string
  default = "eu-west-1"
}

variable "prefixe" {
  type        = string
  description = "Préfixe unique des buckets (les noms S3 sont globaux)"
  default     = "formation-tf-demo"
}

# Provider par défaut + provider "alias" pour la 2e région
provider "aws" {
  region = var.region_principale

  default_tags {
    tags = { gere_par = "terraform", projet = "multi-region" }
  }
}

provider "aws" {
  alias  = "replica"
  region = var.region_replica

  default_tags {
    tags = { gere_par = "terraform", projet = "multi-region" }
  }
}

# Le module reçoit les DEUX configurations de provider explicitement
module "donnees" {
  source = "./modules/bucket-replique"

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }

  prefixe = var.prefixe
}

output "buckets" {
  value = {
    source  = module.donnees.bucket_source
    replica = module.donnees.bucket_replica
  }
}
