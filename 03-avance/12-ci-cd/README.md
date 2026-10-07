# 12 — CI/CD pour Terraform

## Principes
1. **Tout passe par une PR** : jamais d'`apply` depuis un poste en production.
2. **Plan sur PR → relecture humaine → apply sur `main`**, avec **le plan exact relu** (`terraform apply tfplan`).
3. **Identités éphémères** : OIDC (GitHub Actions ↔ AWS/Azure/GCP) plutôt que clés d'accès stockées.
4. **Moindre privilège** : le rôle du plan est en *lecture seule*, celui de l'apply est limité à l'environnement.
5. **Un seul apply à la fois** par état (`concurrency`) + verrou du backend.
6. **Qualité automatique** : `fmt -check`, `validate`, `tflint`, `checkov`/`trivy`, `terraform test`, policies OPA.
7. **Détection de dérive** : un `plan -detailed-exitcode` planifié (cron) : code `2` = écart ⇒ alerte.
8. **Versions épinglées** : Terraform (`required_version`), providers (lock file), modules (tags).

## Codes de sortie de `plan -detailed-exitcode`
`0` = aucun changement · `1` = erreur · `2` = changements à appliquer.

## Options de plateforme
| Option | Avantages |
|--------|-----------|
| GitHub Actions / GitLab CI / Azure DevOps + OIDC | simple, gratuit, flexible ; vous gérez les garde-fous |
| HCP Terraform / Terraform Enterprise | runs, state, RBAC, policies (Sentinel/OPA), variable sets, drift detection intégrés |
| Atlantis, Spacelift, env0, Scalr… | orchestration PR, `atlantis plan/apply` en commentaires |
| OpenTofu (fork open source) | mêmes workflows, licence MPL ; voir [docs/07-ecosysteme.md](../../docs/07-ecosysteme.md) |

## Exercices
1. Lisez [`solution/terraform-pipeline.yml`](solution/terraform-pipeline.yml). Identifiez : où est l'OIDC ? où est l'approbation ? comment évite-t-on 2 apply simultanés ?
2. Ouvrez la CI **de ce dépôt** : [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml). Que vérifie-t-elle ?
3. Installez `pre-commit` et le fichier `.pre-commit-config.yaml` : committez un fichier mal formaté, observez l'échec.
4. Écrivez un workflow cron hebdomadaire de détection de dérive qui ouvre une *issue* si `plan -detailed-exitcode` retourne `2`.
5. Défi : configurez un rôle IAM AWS avec *trust policy* OIDC limitée à `repo:<org>/<repo>:ref:refs/heads/main` pour l'apply, et à `pull_request` pour le plan (lecture seule).

## Trust policy OIDC (exemple)
```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
    "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:mon-org/mon-repo:ref:refs/heads/main" }
  }
}
```
