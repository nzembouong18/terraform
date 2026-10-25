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
variable "db_password" {       # jamais écrit dans state/plan
  type = string
  ephemeral = true
}
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

## Comprendre en profondeur

### Modèle de menace : que protège-t-on ?
| Actif | Menace | Mesures |
|-------|--------|---------|
| Le **code** (`.tf`) | modification malveillante, dépendance compromise | PR obligatoires, revue, `CODEOWNERS`, versions épinglées |
| Le **state** | lecture (vol de secrets), écriture (détruire/rediriger) | backend chiffré, IAM minimal, versioning, journalisation |
| Les **identifiants** de Terraform | vol, abus | OIDC, durée courte, moindre privilège |
| Le **pipeline** | exécution de code arbitraire (un `plan` exécute des data sources et des providers) | runners isolés, branches protégées, pas de secrets sur les forks |
| La **chaîne d'approvisionnement** | provider/module piégé | lock file, signatures, registry interne |
| L'**infrastructure produite** | mauvaise configuration (bucket public, port ouvert) | analyse statique, policy as code |

Point souvent oublié : un `terraform plan` **exécute du code tiers** (providers, data source `external`, `local-exec`…). Sur une PR provenant d'un fork, il ne faut pas lui donner de secrets.

### Où mettre un secret ?
```
Source de vérité = coffre (Vault, AWS Secrets Manager, Key Vault, Secret Manager)
        │
        ├── Terraform LIT la valeur (data source / ressource éphémère) pour la passer à un service
        └── OU Terraform ne la voit jamais : l'application la lit elle-même au démarrage via son rôle
```
Option la plus sûre : **Terraform ne manipule pas le secret** (il crée le coffre, les droits d'accès, et laisse l'application ou un autre processus peupler la valeur). Quand il doit le manipuler, utiliser les valeurs **éphémères** et attributs **write-only** pour qu'il n'atterrisse ni dans le plan ni dans le state.

Fournisseurs de secrets : `random_password` (le mot de passe est **dans le state**), `aws_secretsmanager_secret_version`, `vault_kv_secret_v2`… vérifiez toujours si une version `ephemeral` existe.

### Écrire du Terraform sécurisé par défaut
```hcl
resource "aws_s3_bucket_public_access_block" "b" {
  bucket                  = aws_s3_bucket.b.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "b" {
  bucket = aws_s3_bucket.b.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}
```
Check-list générale : chiffrement au repos et en transit, journalisation activée, accès public interdit, **groupes de sécurité** limités (pas de `0.0.0.0/0` sur SSH/RDP), **IAM** sans `*:*`, sauvegardes, versioning, protection contre la suppression.

### Moindre privilège pour les politiques IAM écrites en Terraform
- Éviter `Action = "*"` ou `Resource = "*"` : listez les actions et ressources précises.
- Construire les politiques avec `aws_iam_policy_document` (data source) : syntaxe validée, composable.
- Utiliser des **permission boundaries** et des SCP pour borner ce que Terraform peut créer, même s'il est compromis.
- Pas de rôle unique « admin » : un rôle `réseau`, un rôle `application`, un rôle `lecture`.

### Analyse statique : lire et traiter les résultats
Exemple de sortie Checkov : `CKV_AWS_18: "Ensure the S3 bucket has access logging enabled"`. Trois réponses possibles :
1. **Corriger** (cas par défaut).
2. **Justifier une exception** localement, avec la raison : `#checkov:skip=CKV_AWS_18:journalisation gérée au niveau de l'organisation`.
3. **Désactiver la règle globalement** (rarement légitime ; documenter dans `.checkov.yaml`).

Règle d'hygiène : une exception sans justification écrite est une dette de sécurité. Faire échouer la CI sur les sévérités `HIGH`/`CRITICAL`, avertir sur le reste.

### Gestion des secrets dans le dépôt
- Hook `pre-commit` (`gitleaks`, `detect-secrets`) + analyse CI en second filet.
- `.gitignore` : `*.tfstate*`, `.terraform/`, `*.tfvars` contenant des secrets, `*.pem`, `tfplan`.
- Si un secret a été committé : le **révoquer immédiatement** (le retirer de l'historique ne suffit pas, il est compromis), puis nettoyer (`git filter-repo`).

### Signatures et intégrité de la chaîne d'approvisionnement
- Les providers HashiCorp sont signés (GPG) ; `terraform init` vérifie la signature et les sommes de contrôle du lock file.
- Pour les modules : épingler un **tag** *immuable* (ou un SHA de commit), activer la protection des tags, privilégier une registry interne.
- Surveiller les vulnérabilités avec Dependabot/Renovate/OSV et mettre en place un processus de mise à jour régulier.
- Environnements isolés (« air-gapped ») : miroir de providers (`terraform providers mirror`) et `provider_installation { filesystem_mirror { … } }`.

### Réponse à incident (clé divulguée, state exposé)
1. **Révoquer/tourner** les identifiants concernés (le plus urgent).
2. Auditer les journaux d'accès au state et aux APIs cloud (CloudTrail).
3. Régénérer les secrets contenus dans le state (`-replace` sur les `random_password`, nouvelles clés TLS).
4. Corriger la cause (droit trop large, bucket public), puis publier un post-mortem.

## Exercices
1. Dans `solution/`, `apply` puis cherchez le jeton et le mot de passe dans `terraform.tfstate` (`grep`). Que concluez-vous ?
2. Exécutez `terraform output db_password` puis `-raw`. Pourquoi la 1ʳᵉ commande masque-t-elle ?
3. Installez `tflint` et lancez `tflint --init && tflint` avec le fichier `.tflint.hcl`.
4. Installez `checkov` (`pipx install checkov`) et scannez [`05-projet-final`](../../05-projet-final) : listez 3 findings et corrigez-en un (ex. SG sortant trop large).
5. Écrivez un `.gitignore` et un hook `pre-commit` (`detect-secrets`/`gitleaks`) qui bloque un commit contenant une clé AWS factice.
6. Défi : rédigez un modèle de menace pour un état Terraform (qui peut le lire ? l'écrire ? que contient-il ?).

## Corrigé
[`solution/`](solution/)
