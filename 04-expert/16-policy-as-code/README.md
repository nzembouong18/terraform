# 16 — Policy as code (OPA / Rego)

Objectif : **empêcher** automatiquement les changements non conformes *avant* l'apply.

```
terraform plan -out=tfplan
terraform show -json tfplan > plan.json      # représentation JSON stable du plan
opa eval --data policy/ --input plan.json 'data.terraform.deny'   # ou: conftest test plan.json
```
Le JSON contient `resource_changes[]` avec `type`, `address`, `change.actions` (`create|update|delete|no-op`), `change.before/after`.

## Outils
| Outil | Langage | Contexte |
|-------|---------|----------|
| **OPA / Conftest** | Rego | CI générique, HCP Terraform (policies OPA) |
| **Sentinel** | Sentinel | HCP Terraform / Terraform Enterprise |
| Checkov/Trivy | règles intégrées + custom | analyse statique du code |

## Politiques fournies (`solution/policy/terraform.rego`)
1. Pas d'ACL S3 publique.
2. Tags `projet` et `proprietaire` obligatoires.
3. Pas de suppression de base de données (`aws_db_instance`).
4. Types d'instances EC2 autorisés (FinOps).

Les tests unitaires de politique sont dans `terraform_test.rego` : `opa test policy -v`.

## Exercices
1. Installez `opa`, lancez `opa test policy -v` puis `./check.sh` (échoue volontairement : 3 violations).
2. Ajoutez la règle « aucun Security Group ne doit ouvrir le port 22 à `0.0.0.0/0` » + son test.
3. Générez un **vrai** plan JSON depuis le [projet final](../../05-projet-final) (`terraform plan` nécessite des credentials ; sinon utilisez `fixtures/`) et évaluez-le.
4. Intégrez `check.sh` à la CI : le job échoue si `deny` n'est pas vide.
5. Défi : règle d'**avertissement** (`warn`) vs blocage (`deny`) ; exceptions via une liste `exemptions` dans un fichier `data.json`.

## Corrigé
[`solution/`](solution/)
