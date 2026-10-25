#!/usr/bin/env bash
# Valide TOUS les labs du dépôt (utilisé en local et par la CI).
#   ./scripts/validate-all.sh           -> fmt + validate + tests + apply/destroy des labs hors-ligne
#   ./scripts/validate-all.sh --fast    -> fmt + validate uniquement
# Prérequis : terraform >= 1.9 ; opa (optionnel, pour la policy du lab 16).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAST=false; [ "${1:-}" = "--fast" ] && FAST=true
TF_FLAGS=(-input=false -no-color)
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

# Labs "hors-ligne" : n'utilisent que local/random -> apply/destroy réel possible
OFFLINE=(
  01-debutant/01-premiers-pas/solution
  01-debutant/02-variables-outputs/solution
  01-debutant/03-ressources-data-lifecycle/solution
  02-intermediaire/05-boucles-conditions/solution
  02-intermediaire/06-modules/solution
  02-intermediaire/09-fonctions-templates/solution
  03-avance/13-securite/solution
)
# Labs cloud (AWS) : validate (+ tests avec provider simulé), jamais d'apply
CLOUD=(
  04-expert/14-multi-region-providers/solution
  04-expert/15-module-qualite/solution
  04-expert/15-module-qualite/solution/examples/minimal
  05-projet-final/envs/dev
  05-projet-final/envs/prod
  05-projet-final/modules/reseau
  05-projet-final/modules/application
  06-complements/19-azure/solution
  06-complements/20-gcp/solution
  06-complements/21-kubernetes/solution
)
WITH_TESTS=(
  04-expert/14-multi-region-providers/solution
  05-projet-final/modules/application
  06-complements/19-azure/solution
  06-complements/20-gcp/solution
  06-complements/21-kubernetes/solution
  03-avance/10-tests/solution
  04-expert/15-module-qualite/solution
  05-projet-final/modules/reseau
)
OTHER_VALIDATE=(
  01-debutant/04-state/solution
  02-intermediaire/07-backends-remote-state/solution/socle
  02-intermediaire/07-backends-remote-state/solution/application
  02-intermediaire/08-workspaces-environnements/solution
  03-avance/10-tests/solution
  03-avance/11-refactoring/solution
)

clean() { (cd "$1" && rm -rf out out-test); }

validate() {
  (cd "$ROOT/$1" && terraform fmt -check -recursive >/dev/null \
    && terraform init -backend=false "${TF_FLAGS[@]}" >/dev/null \
    && terraform validate -no-color >/dev/null)
  ok "validate  $1"
}

step "fmt + validate"
for d in "${OFFLINE[@]}" "${CLOUD[@]}" "${OTHER_VALIDATE[@]}"; do validate "$d"; done

step "extraits HCL des cours (syntaxe)"
"$ROOT/scripts/check-snippets.sh"

step "liens Markdown"
"$ROOT/scripts/check-links.sh"

step "workflows YAML"
if python3 -c 'import yaml' 2>/dev/null; then
  for y in .github/workflows/ci.yml 03-avance/12-ci-cd/solution/terraform-pipeline.yml 03-avance/12-ci-cd/solution/.pre-commit-config.yaml; do
    python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$ROOT/$y"
    ok "yaml  $y"
  done
else
  echo "  (PyYAML absent : contrôle YAML ignoré)"
fi
$FAST && exit 0

step "apply / idempotence / destroy (labs hors-ligne)"
for d in "${OFFLINE[@]}"; do
  (
    cd "$ROOT/$d"
    clean .
    terraform apply -auto-approve "${TF_FLAGS[@]}" >/dev/null
    # 2e plan : doit être vide (code 0), sinon la config n'est pas idempotente
    terraform plan -detailed-exitcode "${TF_FLAGS[@]}" >/dev/null
    terraform destroy -auto-approve "${TF_FLAGS[@]}" >/dev/null
    clean .; rm -f terraform.tfstate terraform.tfstate.backup
  )
  ok "apply+destroy  $d"
done

step "lab 04 : moved (renommage sans destruction)"
(
  cd "$ROOT/01-debutant/04-state/solution"
  tmp=$(mktemp -d); cp main.tf "$tmp/"; cd "$tmp"
  sed -e 's/random_pet" "nouveau"/random_pet" "ancien"/' -e 's/random_pet.nouveau/random_pet.ancien/g' \
      -e '/^moved {/,/^}/d' main.tf > v1.tf && mv v1.tf main.tf
  terraform init -backend=false "${TF_FLAGS[@]}" >/dev/null
  terraform apply -auto-approve "${TF_FLAGS[@]}" >/dev/null
  cp "$ROOT/01-debutant/04-state/solution/main.tf" main.tf
  out=$(terraform plan "${TF_FLAGS[@]}")
  echo "$out" | grep -q "has moved to" && echo "$out" | grep -q "0 to destroy"
  terraform destroy -auto-approve "${TF_FLAGS[@]}" >/dev/null
  rm -rf "$tmp"
)
ok "moved  01-debutant/04-state"

step "lab 11 : moved (renommage + déplacement dans un module) puis import"
(
  tmp=$(mktemp -d); cd "$tmp"
  cat > main.tf <<'HCL'
terraform {
  required_providers {
    random = { source = "hashicorp/random" }
    local  = { source = "hashicorp/local" }
  }
}
resource "random_pet" "a" {
  length = 2
}
resource "local_file" "rapport" {
  filename = "${path.root}/out/rapport.txt"
  content  = random_pet.a.id
}
HCL
  terraform init "${TF_FLAGS[@]}" >/dev/null && terraform apply -auto-approve "${TF_FLAGS[@]}" >/dev/null
  rm -rf .terraform.lock.hcl
  cp -r "$ROOT/03-avance/11-refactoring/solution/modules" . && cp "$ROOT/03-avance/11-refactoring/solution/main.tf" main.tf
  terraform init "${TF_FLAGS[@]}" >/dev/null
  out=$(terraform plan "${TF_FLAGS[@]}")
  echo "$out" | grep -q "random_pet.a has moved to random_pet.principal"
  echo "$out" | grep -q "local_file.rapport has moved to module.rapports.local_file.rapport"
  echo "$out" | grep -q "Plan: 0 to add, 0 to change, 0 to destroy"
  terraform destroy -auto-approve "${TF_FLAGS[@]}" >/dev/null
  rm -rf "$tmp"
  # import déclaratif d'un random_id existant
  tmp=$(mktemp -d); cd "$tmp"
  printf 'terraform {\n  required_providers {\n    random = { source = "hashicorp/random" }\n  }\n}\nresource "random_id" "test" {\n  byte_length = 4\n}\noutput "id" {\n  value = random_id.test.b64_url\n}\n' > main.tf
  terraform init "${TF_FLAGS[@]}" >/dev/null && terraform apply -auto-approve "${TF_FLAGS[@]}" >/dev/null
  id=$(terraform output -raw id); mkdir b && cd b
  printf 'terraform {\n  required_providers {\n    random = { source = "hashicorp/random" }\n  }\n}\nimport {\n  to = random_id.test\n  id = "%s"\n}\nresource "random_id" "test" {\n  byte_length = 4\n}\n' "$id" > main.tf
  terraform init "${TF_FLAGS[@]}" >/dev/null
  terraform plan "${TF_FLAGS[@]}" | grep -q "Plan: 1 to import, 0 to add, 0 to change, 0 to destroy"
  terraform apply -auto-approve "${TF_FLAGS[@]}" >/dev/null
  terraform plan -detailed-exitcode "${TF_FLAGS[@]}" >/dev/null
  rm -rf "$tmp"
)
ok "moved + import  lab 11"

step "lab 07 : remote state entre deux stacks"
(
  cd "$ROOT/02-intermediaire/07-backends-remote-state/solution"
  rm -rf etat
  for s in socle application; do (cd $s && terraform init "${TF_FLAGS[@]}" >/dev/null && terraform apply -auto-approve "${TF_FLAGS[@]}" >/dev/null); done
  grep -q "$(cd socle && terraform output -raw nom_cluster)" application/out/deploiement.txt
  for s in application socle; do (cd $s && terraform destroy -auto-approve "${TF_FLAGS[@]}" >/dev/null; rm -rf out .terraform .terraform.lock.hcl); done
  rm -rf etat
)
ok "remote_state  lab 07"

step "lab 08 : workspaces"
(
  cd "$ROOT/02-intermediaire/08-workspaces-environnements/solution"
  terraform init "${TF_FLAGS[@]}" >/dev/null
  terraform workspace new prod >/dev/null
  terraform apply -auto-approve "${TF_FLAGS[@]}" >/dev/null
  grep -q "replicas=3" out/prod.txt
  terraform destroy -auto-approve "${TF_FLAGS[@]}" >/dev/null
  terraform workspace select default >/dev/null && terraform workspace delete prod >/dev/null
  rm -rf out terraform.tfstate.d
)
ok "workspaces  lab 08"

step "terraform test"
for d in "${WITH_TESTS[@]}"; do
  (cd "$ROOT/$d" && terraform init -backend=false "${TF_FLAGS[@]}" >/dev/null && terraform test -no-color >/dev/null)
  ok "test  $d"
done

step "lab 22 : debug (les exercices doivent échouer, les solutions passer)"
for n in 01 02 03 04 05 06; do
  (
    cd "$ROOT/06-complements/22-debug/exercices/$n"
    if terraform init "${TF_FLAGS[@]}" >/dev/null 2>&1 && terraform plan "${TF_FLAGS[@]}" >/dev/null 2>&1; then
      echo "L'exercice $n devrait échouer" >&2; exit 1
    fi
    rm -rf .terraform .terraform.lock.hcl
    cd "$ROOT/06-complements/22-debug/solutions/$n"
    terraform init "${TF_FLAGS[@]}" >/dev/null && terraform plan "${TF_FLAGS[@]}" >/dev/null
    rm -rf .terraform .terraform.lock.hcl
  )
  ok "debug  $n"
done

if command -v opa >/dev/null; then
  step "policy-as-code (OPA)"
  (
    cd "$ROOT/04-expert/16-policy-as-code/solution"
    opa test policy >/dev/null
    ./check.sh fixtures/plan-conforme.json >/dev/null            # doit passer
    if ./check.sh fixtures/plan-non-conforme.json >/dev/null; then # doit échouer
      echo "check.sh aurait dû refuser plan-non-conforme.json" >&2; exit 1
    fi
  )
  ok "opa test + check.sh (plan conforme accepté, non conforme refusé)"
fi
printf '\n\033[32mTout est vert.\033[0m\n'
