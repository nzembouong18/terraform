provider "aws" {
  region = "eu-west-3"
}

module "bucket" {
  source = "../.."

  nom = "exemple-formation-tf-minimal"
  tags = {
    projet = "demo"
  }
}

output "arn" {
  value = module.bucket.arn
}
