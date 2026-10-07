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
)
WITH_TESTS=(
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

if command -v opa >/dev/null; then
  step "policy-as-code (OPA)"
  (cd "$ROOT/04-expert/16-policy-as-code/solution" && opa test policy >/dev/null)
  ok "opa test"
fi
printf '\n\033[32mTout est vert.\033[0m\n'
