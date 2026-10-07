# Politique évaluée sur la sortie JSON d'un plan : terraform show -json tfplan
# Utilisable avec OPA (`opa eval`) ou Conftest (`conftest test plan.json`).
package terraform

import rego.v1

# Toutes les ressources qui vont être créées ou modifiées
changements contains rc if {
	some rc in input.resource_changes
	some action in rc.change.actions
	action in {"create", "update"}
}

# Règle 1 : aucun bucket S3 avec ACL publique
deny contains msg if {
	some rc in changements
	rc.type == "aws_s3_bucket_acl"
	rc.change.after.acl in {"public-read", "public-read-write"}
	msg := sprintf("%s : ACL publique interdite (%s)", [rc.address, rc.change.after.acl])
}

# Règle 2 : tags obligatoires sur les ressources taguables
tags_obligatoires := {"projet", "proprietaire"}

deny contains msg if {
	some rc in changements
	rc.type in {"aws_instance", "aws_s3_bucket", "aws_db_instance"}
	tags := object.get(rc.change.after, "tags", {})
	manquants := tags_obligatoires - {k | some k, _ in tags}
	count(manquants) > 0
	msg := sprintf("%s : tags manquants %v", [rc.address, sort(manquants)])
}

# Règle 3 : pas de suppression d'une base de données sans revue explicite
deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_db_instance"
	"delete" in rc.change.actions
	msg := sprintf("%s : suppression de base de données interdite", [rc.address])
}

# Règle 4 : types d'instances EC2 autorisés
types_autorises := {"t3.micro", "t3.small", "t3.medium"}

deny contains msg if {
	some rc in changements
	rc.type == "aws_instance"
	not rc.change.after.instance_type in types_autorises
	msg := sprintf("%s : type %s non autorisé", [rc.address, rc.change.after.instance_type])
}
