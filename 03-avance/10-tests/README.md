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

## Comprendre en profondeur

### Pourquoi tester de l'infrastructure ?
Une erreur de code applicatif se corrige par un déploiement ; une erreur d'infrastructure peut **supprimer une base**, **ouvrir un port** ou **coûter cher** avant d'être vue. Les tests donnent un retour *avant* l'apply : ils protègent la logique (conditions, `for_each`, calculs réseau), documentent le comportement attendu d'un module et autorisent le refactoring sans peur.

Ce que l'on teste réellement :
- la **logique** : « avec `chiffrement = true`, la ressource KMS existe » ;
- les **contrats** : « une valeur invalide est rejetée » ;
- les **non-régressions** : « renommer une ressource ne la détruit pas » ;
- (en intégration) le **comportement réel** : « le bucket accepte bien un objet ».

### Structure d'un fichier de test
```hcl
# tests/unitaires.tftest.hcl
provider "aws" { region = "eu-west-3" }          # config de provider pour le test

variables {                                      # variables par défaut de tout le fichier
  nom = "demo"
  ports = [80, 443]
}

run "ports_valides" {
  command = plan                                 # ne crée rien
  assert {
    condition     = length(local.regles) == 2
    error_message = "Une règle par port attendue."
  }
}

run "creation_reelle" {
  command = apply                                # crée vraiment (détruit à la fin du fichier)
  assert {
    condition     = aws_s3_bucket.b.bucket == "demo-logs"
    error_message = "Nom de bucket inattendu."
  }
}

run "verifie_la_sortie_precedente" {
  command = plan
  variables { nom = run.creation_reelle.nom_complet }   # un run peut consommer les sorties d'un run précédent
  assert {
    condition = output.nom == "demo-logs"
    error_message = "…"
  }
}
```
Ce qui est accessible dans une `assert` : variables, `locals`, outputs, attributs des ressources, `run.<nom>.<output>`. Avec `command = plan`, les valeurs **inconnues avant apply** (IDs) ne peuvent pas être testées.

### Mock providers et overrides : tester sans cloud
```hcl
mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::mock", id = "mock" }   # valeurs calculées simulées
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}
override_resource {
  target = aws_kms_key.cle
  values = { arn = "arn:aws:kms:eu-west-3:123456789012:key/mock" }
}
```
Les mocks permettent d'exécuter un **`apply` simulé** : rapide, gratuit, sans credentials, idéal en CI sur chaque PR. Limite : un mock ne détecte **pas** une erreur que l'API réelle aurait refusée (quota, nom déjà pris, droits manquants). D'où la pyramide : beaucoup de tests simulés, quelques tests réels.

### Tester les erreurs attendues
```hcl
run "refuse_nom_vide" {
  command         = plan
  variables { nom = "" }
  expect_failures = [var.nom]        # réussit SI la validation de var.nom échoue
}
```
`expect_failures` accepte des variables, ressources, outputs, `check` ou conditions. Sans lui, une validation qui échoue fait échouer le test.

### Cycle des tests en CI
```yaml
- run: terraform init -backend=false
- run: terraform fmt -check -recursive
- run: terraform validate
- run: terraform test              # unitaires + mocks sur chaque PR
# nightly : terraform test -filter=tests/integration.tftest.hcl   (compte de test isolé, budget plafonné)
```
Pour les tests d'intégration réels : **compte/projet dédié**, noms uniques (`random_id`), nettoyage garanti (le `destroy` automatique peut échouer : prévoyez un balayeur de ressources orphelines), plafonds de budget.

### `terraform test` vs Terratest
| | `terraform test` | Terratest (Go) |
|--|------------------|----------------|
| Langage | HCL | Go |
| Installation | intégré à Terraform | bibliothèque Go |
| Forces | simple, mocks, natif | logique de test riche : HTTP, SSH, API cloud, retries |
| Quand | modules, logique, contrats | scénarios bout en bout complexes |

### `check`, `precondition`, `validation` : quel contrat où ?
| Mécanisme | Quand il s'exécute | Si faux | Usage |
|-----------|-------------------|---------|-------|
| `validation` (variable) | à l'évaluation des entrées | **erreur** | forme des paramètres |
| `precondition` | avant de créer/modifier la ressource | **erreur** | hypothèses (data sources, entrées croisées) |
| `postcondition` | après création | **erreur** | garantie sur le résultat |
| `check` | en fin de plan/apply | **avertissement** | supervision continue, SLO simples |
| `terraform test` | à la demande / en CI | échec du test | comportement du module |

### Que tester en priorité ?
1. Les **validations** (cas valides, invalides, limites : 0, 1, 65535, 65536).
2. Les **conditions** (`count = cond ? 1 : 0`) : les deux branches.
3. Les **transformations** complexes (`for`, `flatten`, `cidrsubnet`).
4. La **sécurité par défaut** (chiffrement activé, accès public bloqué).
5. L'**absence de destruction** lors d'un renommage (`moved`).

## Exercices
1. Lancez `terraform init && terraform test` dans `solution/`. Lisez les 3 fichiers de test.
2. Cassez volontairement la logique : remplacez `p > 0` par `p >= 0` dans `main.tf`. Quel test échoue (`ports_invalides_sont_filtres`) ? Lisez le message, puis remettez le code. Pourquoi le test `nom_valide_produit_le_bon_chemin` reste-t-il vert ?
3. Ajoutez un test `plan` vérifiant que `nom = "web"` produit `out/web.conf`.
4. Ajoutez une validation sur `ports` (pas de doublons : `length(var.ports) == length(distinct(var.ports))`) **et** son test `expect_failures`.
5. Appliquez la même méthode au module [`15-module-qualite`](../../04-expert/15-module-qualite/solution/tests/module.tftest.hcl) (provider AWS simulé).
6. Défi : lisez [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) et [`scripts/validate-all.sh`](../../scripts/validate-all.sh) : où `terraform test` est-il exécuté ? Ajoutez un job séparé qui n'exécute que les tests (`terraform test -filter=tests/unitaires.tftest.hcl`).

## Corrigé
[`solution/`](solution/) — `main.tf`, `tests/unitaires`, `integration`, `mock`.
