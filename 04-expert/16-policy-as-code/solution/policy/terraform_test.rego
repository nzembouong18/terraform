package terraform_test

import rego.v1

import data.terraform

plan_conforme := {"resource_changes": [{
	"address": "aws_instance.web",
	"type": "aws_instance",
	"change": {
		"actions": ["create"],
		"after": {"instance_type": "t3.micro", "tags": {"projet": "x", "proprietaire": "y"}},
	},
}]}

test_plan_conforme_ok if {
	count(terraform.deny) == 0 with input as plan_conforme
}

test_tags_manquants_refuses if {
	plan := {"resource_changes": [{
		"address": "aws_s3_bucket.b",
		"type": "aws_s3_bucket",
		"change": {"actions": ["create"], "after": {"tags": {"projet": "x"}}},
	}]}
	count(terraform.deny) == 1 with input as plan
}

test_type_instance_refuse if {
	plan := {"resource_changes": [{
		"address": "aws_instance.gros",
		"type": "aws_instance",
		"change": {"actions": ["create"], "after": {"instance_type": "m5.24xlarge", "tags": {"projet": "x", "proprietaire": "y"}}},
	}]}
	count(terraform.deny) == 1 with input as plan
}

test_suppression_db_refusee if {
	plan := {"resource_changes": [{
		"address": "aws_db_instance.prod",
		"type": "aws_db_instance",
		"change": {"actions": ["delete"], "after": null},
	}]}
	count(terraform.deny) == 1 with input as plan
}
