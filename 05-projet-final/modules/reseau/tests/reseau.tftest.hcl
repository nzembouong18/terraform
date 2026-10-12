mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
    }
  }
}

variables {
  nom = "test"
}

run "deux_zones_une_nat_par_defaut" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.prive) == 2
    error_message = "2 sous-réseaux publics et 2 privés attendus."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Une seule NAT en mode économique."
  }
}

run "haute_dispo_une_nat_par_zone" {
  command = plan

  variables {
    nb_zones           = 3
    nat_gateway_unique = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "Une NAT par zone attendue."
  }
}

run "cidr_invalide" {
  command = plan

  variables {
    cidr = "pas-un-cidr"
  }

  expect_failures = [var.cidr]
}
