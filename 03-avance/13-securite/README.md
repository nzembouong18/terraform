# 13 — Sécurité

## 1. Les secrets
| ❌ À éviter | ✅ À faire |
|------------|-----------|
| secret en dur dans `.tf` / `.tfvars` versionné | `TF_VAR_x` injecté par la CI, ou lecture dans un coffre (Vault, AWS Secrets Manager, Azure Key Vault) |
| `output` d'un mot de passe | ne pas l'exposer ; le stocker directement dans le coffre |
| clés d'accès longue durée | OIDC / rôles temporaires |

`sensitive = true` **masque l'affichage** mais **n'empêche pas** l'écriture dans le state et le plan → **le state est un artefact sensible**.

### Valeurs éphémères (Terraform ≥ 1.10) et write-only (≥ 1.11)
```hcl
variable "db_password" { type = string  ephemeral = true }       # jamais écrit dans state/plan
ephemeral "aws_secretsmanager_secret_version" "db" { secret_id = "prod/db" }
resource "aws_db_instance" "main" {
  password_wo         = ephemeral.aws_secretsmanager_secret_version.db.secret_string
  password_wo_version = 1                                          # incrémenter pour re-pousser
}
```
Cela supprime le secret du state quand le provider le supporte (attributs `*_wo`).

## 2. Protéger le state
- Backend **chiffré** (SSE-KMS), **versionné**, accès IAM minimal (lecture du state ≈ lecture des secrets).
- Interdire l'accès au bucket aux humains en dehors d'un rôle d'urgence audité.
- Jamais de state dans git.

## 3. Analyse statique (shift-left)
| Outil | Rôle |
|-------|------|
| `tflint` | erreurs de provider (types d'instance inexistants…), conventions |
| `checkov`, `trivy config`, `tfsec` (fusionné dans trivy) | mauvaises pratiques de sécurité (bucket public, SG ouvert, chiffrement absent) |
| `terraform-docs` | documentation des modules |
| OPA / Sentinel | politiques d'entreprise sur le **plan** (module 16) |

## 4. Chaîne d'approvisionnement
- Épingler providers (`~>` + lock file avec `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`).
- Épingler les modules distants à un **tag/commit** ; privilégier une registry interne.
- Relire le diff du lock file en PR (Dependabot/Renovate savent mettre à jour providers et modules).

## 5. Principe du moindre privilège pour Terraform lui-même
Un compte « admin » pour Terraform est une cible de choix. Séparez les rôles (plan/apply, par environnement), limitez par *permission boundaries*, et auditez via CloudTrail.

## Exercices
1. Dans `solution/`, `apply` puis cherchez le jeton et le mot de passe dans `terraform.tfstate` (`grep`). Que concluez-vous ?
2. Exécutez `terraform output db_password` puis `-raw`. Pourquoi la 1ʳᵉ commande masque-t-elle ?
3. Installez `tflint` et lancez `tflint --init && tflint` avec le fichier `.tflint.hcl`.
4. Installez `checkov` (`pipx install checkov`) et scannez [`05-projet-final`](../../05-projet-final) : listez 3 findings et corrigez-en un (ex. SG sortant trop large).
5. Écrivez un `.gitignore` et un hook `pre-commit` (`detect-secrets`/`gitleaks`) qui bloque un commit contenant une clé AWS factice.
6. Défi : rédigez un modèle de menace pour un état Terraform (qui peut le lire ? l'écrire ? que contient-il ?).

## Corrigé
[`solution/`](solution/)
