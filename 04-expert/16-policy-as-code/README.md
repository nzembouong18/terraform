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

## Comprendre en profondeur

### Pourquoi une politique en plus de la revue humaine ?
Une relecture humaine est faillible et ne passe pas à l'échelle (50 équipes, 500 PR par semaine). Les règles d'entreprise (« pas de bucket public », « tag `proprietaire` obligatoire », « pas d'instance > 8xlarge sans accord ») doivent être appliquées **de façon identique, automatique et traçable**. Le *policy as code* remplace un document de recommandations par un test exécutable.

Différence avec l'analyse statique (Checkov, tfsec) : celle-ci lit le **code** ; la politique sur le plan lit ce qui va **réellement** changer, valeurs calculées incluses (`known after apply` exclues), et sait distinguer *création* / *modification* / *suppression*.

### Anatomie du JSON d'un plan
```json
{
  "format_version": "1.2",
  "terraform_version": "1.9.8",
  "resource_changes": [{
    "address": "aws_s3_bucket.logs",
    "type": "aws_s3_bucket",
    "change": {
      "actions": ["create"],
      "before": null,
      "after":  { "bucket": "acme-logs", "tags": { "projet": "x" } },
      "after_unknown": { "arn": true, "id": true }
    }
  }],
  "configuration": { "…": "…" },
  "planned_values": { "…": "…" }
}
```
- `change.actions` : `["create"]`, `["update"]`, `["delete"]`, `["delete","create"]` (remplacement), `["no-op"]`.
- `change.after_unknown` : attributs encore inconnus (une politique ne peut pas les juger → décider de les laisser passer ou de les refuser).
- `configuration` : le code résolu (modules, références) pour vérifier des relations.

### Rego : les bases
Rego est un langage **déclaratif** : on écrit des règles qui énoncent *quand* une valeur est vraie.
```rego
package terraform

import rego.v1

# Un ensemble de messages de violation.
deny contains msg if {
    some rc in input.resource_changes          # parcourt toutes les ressources
    rc.type == "aws_s3_bucket_acl"
    rc.change.after.acl in {"public-read", "public-read-write"}
    msg := sprintf("%s: ACL publique interdite", [rc.address])
}

# Aide réutilisable
creations contains rc if {
    some rc in input.resource_changes
    "create" in rc.change.actions
}
```
Concepts clés : `input` (le JSON), `data` (données de configuration, ex. liste d'exceptions), **règles** (`deny`, `warn`), **ensembles** (`contains`), `some … in` pour parcourir, `sprintf` pour les messages. Toutes les conditions d'un corps de règle sont des **ET** logiques ; plusieurs définitions de la même règle sont des **OU**.

### Un modèle de politique robuste
```rego
tags_obligatoires := {"projet", "proprietaire"}

deny contains msg if {
    some rc in creations
    startswith(rc.type, "aws_")
    tags := object.get(rc.change.after, "tags", {})
    manquants := tags_obligatoires - {k | some k, _ in tags}
    count(manquants) > 0
    msg := sprintf("%s: tags manquants %v", [rc.address, manquants])
}
```
Construire en **sous-ensembles lisibles** (`creations`, `suppressions`) puis combiner. Préférer des messages qui disent **quoi corriger**.

### Tester une politique
```rego
test_acl_publique_refusee if {
    deny[_] with input as {"resource_changes": [{
        "address": "aws_s3_bucket_acl.x", "type": "aws_s3_bucket_acl",
        "change": {"actions": ["create"], "after": {"acl": "public-read"}}
    }]}
}
```
`opa test policy -v` exécute ces tests. Tester **aussi les cas passants** : une politique qui refuse tout est facile à écrire et inutilisable. Visez 100 % de couverture : `opa test --coverage`.

### Niveaux d'application
| Niveau | Effet | Usage |
|--------|-------|-------|
| `advisory` / `warn` | information | adoption progressive, règles nouvelles |
| `soft-mandatory` | bloque, **contournable** par un rôle autorisé | règles avec exceptions possibles |
| `hard-mandatory` / `deny` | bloque, non contournable | sécurité, conformité |

Déployez une nouvelle règle en `warn` pendant 1–2 semaines pour mesurer son impact avant de la passer en `deny`.

### Exceptions et gouvernance
- Liste d'exceptions **datée et justifiée** dans `data.json` (`{"adresse": "aws_s3_bucket.legacy", "expire": "2026-03-31", "raison": "…"}`), vérifiée par la politique elle-même.
- Pas d'exception « pour toujours » : une date d'expiration force le réexamen.
- Propriétaire des règles identifié (équipe sécurité/plateforme) et processus de revue des changements de politique (elles aussi vivent dans Git, avec des tests).

### Où exécuter les politiques ?
1. **Localement / pre-commit** (`conftest`) : retour immédiat au développeur.
2. **En CI sur la PR** : barrière obligatoire, résultat dans la PR.
3. **Dans la plateforme** (HCP Terraform : policy sets OPA ou Sentinel) : contrôle central, non contournable par un fork du pipeline.
4. **En continu côté cloud** (AWS Config, Azure Policy, GCP Org Policy, SCP) : filet de sécurité pour ce qui échappe à Terraform. Une politique de plan ne protège pas contre une modification manuelle ; combinez les deux.

### Sentinel en bref
Langage propre à HashiCorp (HCP Terraform/Enterprise), imports `tfplan/v2`, `tfconfig/v2`, `tfstate/v2`, niveaux d'application intégrés, tests via `sentinel test`. Mêmes principes que Rego ; choisir selon l'écosystème (OPA est ouvert et transverse : Kubernetes, API, CI).

### Pièges
- Les valeurs **inconnues** (`after_unknown`) ne peuvent pas être évaluées : décidez explicitement du comportement.
- Une ressource **modifiée** n'est pas forcément une ressource **conforme** : évaluez `after`, pas seulement les créations.
- Les ressources dans des **modules** ont une adresse `module.x.…` : n'ancrez pas vos règles sur l'adresse mais sur le `type`.
- Les politiques trop strictes génèrent des contournements : suivez le taux de refus et les exceptions.

## Exercices
1. Installez `opa`, lancez `opa test policy -v` puis `./check.sh` (échoue volontairement : 3 violations).
2. Ajoutez la règle « aucun Security Group ne doit ouvrir le port 22 à `0.0.0.0/0` » + son test.
3. Générez un **vrai** plan JSON depuis le [projet final](../../05-projet-final) (`terraform plan` nécessite des credentials ; sinon utilisez `fixtures/`) et évaluez-le.
4. Intégrez `check.sh` à la CI : le job échoue si `deny` n'est pas vide.
5. Défi : règle d'**avertissement** (`warn`) vs blocage (`deny`) ; exceptions via une liste `exemptions` dans un fichier `data.json`.

## Corrigé
[`solution/`](solution/)
