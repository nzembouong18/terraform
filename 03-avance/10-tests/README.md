# 10 — Tester son code Terraform

## La pyramide de tests IaC

| Niveau | Outil | Coût | Ce qu'on vérifie |
|--------|-------|------|------------------|
| Statique | `fmt`, `validate`, `tflint`, `checkov`/`trivy` | gratuit, secondes | syntaxe, conventions, failles connues |
| Contrat | `variable validation`, `precondition`/`postcondition`, `check` | gratuit | entrées/sorties cohérentes |
| Unitaire | `terraform test` (`command = plan`, `mock_provider`) | gratuit, rapide | logique des `locals`, conditions, nombres de ressources |
| Intégration | `terraform test` (`command = apply`) / Terratest | réel (cloud) | la ressource se crée vraiment et fonctionne |
| Politique | OPA/Conftest, Sentinel | gratuit | conformité (voir [module 16](../../04-expert/16-policy-as-code/README.md)) |

## `terraform test` (≥ 1.6)
Fichiers `*.tftest.hcl` dans `tests/` ou à la racine.

```hcl
variables { nom = "demo" }                  # valeurs globales du fichier

run "cas_nominal" {
  command = plan                           # ou apply (défaut)
  variables { ports = [80, 443] }          # surcharge pour ce run
  assert {
    condition     = output.nb_ports == 2
    error_message = "2 ports attendus"
  }
}
run "entree_invalide" {
  command         = plan
  variables { nom = "ab" }
  expect_failures = [var.nom]              # le test PASSE si la validation échoue
}
```
- Les `run` s'exécutent **dans l'ordre** et partagent le state du fichier ; les ressources créées par `apply` sont **détruites automatiquement** à la fin.
- `mock_provider "aws" {}` (≥ 1.7) : provider simulé → tests unitaires **sans credentials**. `mock_data` / `mock_resource` fournissent des valeurs par défaut.
- `override_resource`, `override_data`, `override_module` pour forcer des valeurs.
- `terraform test -filter=tests/unitaires.tftest.hcl`, `-verbose` pour afficher les plans.
- Un `run` peut cibler un module (`module { source = "./setup" }`) pour préparer des prérequis.

## Blocs `check` (≥ 1.5)
Vérifications **non bloquantes** (warning) pour la supervision continue :
```hcl
check "site_up" {
  data "http" "ping" { url = "https://exemple.org" }
  assert {
    condition     = data.http.ping.status_code == 200
    error_message = "Site indisponible"
  }
}
```

## Exercices
1. Lancez `terraform init && terraform test` dans `solution/`. Lisez les 3 fichiers de test.
2. Cassez volontairement la logique (`p > 0 && p < 65535`) : quel test échoue ? Lisez le message.
3. Ajoutez un test `plan` vérifiant que `nom = "web"` produit `out/web.conf`.
4. Ajoutez une validation sur `ports` (pas de doublons : `length(var.ports) == length(distinct(var.ports))`) **et** son test `expect_failures`.
5. Appliquez la même méthode au module [`15-module-qualite`](../../04-expert/15-module-qualite/solution/tests/module.tftest.hcl) (provider AWS simulé).
6. Défi : ajoutez à la CI un job `terraform test` (voir [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)).

## Corrigé
[`solution/`](solution/) — `main.tf`, `tests/unitaires`, `integration`, `mock`.
