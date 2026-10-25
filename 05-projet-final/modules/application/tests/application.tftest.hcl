mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      insecure_value = "ami-0123456789abcdef0"
      value          = "ami-0123456789abcdef0"
    }
  }
}

variables {
  nom             = "test-app"
  vpc_id          = "vpc-12345678"
  subnets_publics = ["subnet-aaaa1111", "subnet-bbbb2222"]
  subnets_prives  = ["subnet-cccc3333", "subnet-dddd4444"]
}

run "securite_par_defaut" {
  command = plan

  assert {
    condition     = aws_launch_template.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 doit être obligatoire."
  }

  assert {
    condition     = aws_launch_template.this.image_id == "ami-0123456789abcdef0"
    error_message = "L'AMI doit venir du paramètre SSM."
  }

  assert {
    condition     = aws_autoscaling_group.this.health_check_type == "ELB"
    error_message = "L'ASG doit s'appuyer sur les health checks de l'ALB."
  }
}

run "capacite_incoherente_refusee" {
  command = plan

  variables {
    capacite = { min = 3, max = 2, desired = 1 }
  }

  expect_failures = [var.capacite]
}
