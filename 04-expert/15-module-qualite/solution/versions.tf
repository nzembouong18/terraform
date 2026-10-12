terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 6.0" # un module borne ses providers, il ne les configure PAS
    }
  }
}
