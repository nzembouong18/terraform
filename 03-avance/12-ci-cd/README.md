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

## Comprendre en profondeur

### Pourquoi industrialiser le déploiement ?
Un `apply` lancé depuis un poste pose quatre problèmes : **traçabilité** (qui a fait quoi, avec quel code ?), **reproductibilité** (versions d'outils différentes), **sécurité** (des identifiants puissants sur des laptops), **revue** (rien n'oblige à relire le plan). Un pipeline fait du plan un **objet de revue** et de l'apply une **opération contrôlée**.

### Le flux de référence (GitOps pour l'infrastructure)
```
 branche feature ──► Pull Request ──► [CI] fmt · validate · tflint · checkov · test · plan
                                         │  (plan posté en commentaire, rôle LECTURE SEULE)
                                         ▼
                                  relecture humaine + approbation
                                         │
                                         ▼  merge sur main
                                  [CD] apply du plan approuvé (rôle ÉCRITURE, environnement protégé)
                                         │
                                         ▼
                                  tests post-déploiement + notification
```
Variantes selon l'environnement : `dev` appliqué automatiquement au merge ; `prod` après **approbation manuelle** (GitHub *environments* avec reviewers, GitLab *protected environments*).

### Le plan est un artefact
```bash
terraform plan -out=tfplan -input=false          # en PR
terraform show -no-color tfplan > plan.txt       # commentaire lisible dans la PR
terraform show -json tfplan > plan.json          # analyse par policies / Infracost
terraform apply -input=false tfplan              # applique EXACTEMENT ce qui a été relu
```
Appliquer un **plan sauvegardé** garantit que ce qui est exécuté est ce qui a été relu. Si le state a changé entre-temps, Terraform refuse (plan périmé) : relancez le plan. Le fichier de plan contient des secrets : stockez-le comme artefact **privé** et à durée de vie courte.

### Authentification sans secret : OIDC
Au lieu de stocker `AWS_ACCESS_KEY_ID` dans la CI, le runner présente un **jeton signé** (OIDC) au cloud, qui l'échange contre des **identifiants temporaires** (~1 h) pour un rôle précis.
```yaml
permissions:
  id-token: write          # autorise la demande du jeton OIDC
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/terraform-plan
      aws-region: eu-west-3
```
La *trust policy* du rôle restreint **qui** peut l'assumer : dépôt, branche, environnement (condition `sub`). Deux rôles : `plan` (lecture seule + lecture du state) pour les PR, `apply` (droits d'écriture) uniquement pour `main`/l'environnement protégé.

### Concurrence et ordre
- `concurrency: { group: terraform-${{ matrix.env }}, cancel-in-progress: false }` : un seul apply par état.
- Plusieurs couches (réseau → plateforme → apps) : définir l'ordre via des jobs `needs:` ou un orchestrateur (Terragrunt `run-all`, Stacks, Spacelift).
- `-lock-timeout=10m` évite les échecs inutiles quand deux pipelines se croisent.

### Détection de dérive
```yaml
on: { schedule: [ { cron: "0 6 * * 1-5" } ] }
permissions: { id-token: write, contents: read, issues: write }   # OIDC + création d'issue
steps:
  # `outputs.exitcode` n'existe que si hashicorp/setup-terraform tourne avec terraform_wrapper: true (défaut)
  - run: terraform plan -detailed-exitcode -input=false
    id: plan
    continue-on-error: true
  - if: steps.plan.outcome == 'failure' && steps.plan.outputs.exitcode == '2'
    run: gh issue create --title "Dérive détectée" --body "Voir le run $GITHUB_RUN_ID"
    env:
      GH_TOKEN: ${{ github.token }}      # gh a besoin d'un jeton
```
Une dérive est un **signal** : soit une intervention manuelle non autorisée, soit un attribut géré ailleurs (autoscaling) qu'il faut ignorer explicitement.

### Outils de qualité à brancher
| Étape | Outil | Bloque la PR ? |
|-------|-------|:--:|
| Formatage | `terraform fmt -check -recursive` | ✅ |
| Syntaxe | `terraform validate` | ✅ |
| Lint | `tflint` | ✅ |
| Sécurité | `checkov`, `trivy config` | ✅ (sévérité haute) |
| Secrets | `gitleaks`, `detect-secrets` | ✅ |
| Tests | `terraform test` | ✅ |
| Politique | `conftest`/OPA sur `plan.json` | ✅ |
| Coût | Infracost | ⚠️ commentaire |
| Documentation | `terraform-docs` | ⚠️ vérifie qu'elle est à jour |

### Gestion des versions dans la CI
- Épingler Terraform : `hashicorp/setup-terraform` avec `terraform_version`, ou un fichier `.terraform-version` (tfenv/mise).
- Cacher les providers (`TF_PLUGIN_CACHE_DIR`) pour accélérer les jobs.
- Versionner `.terraform.lock.hcl` avec les hash de **toutes** les plateformes (`terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`) : la CI Linux et les postes macOS utilisent les mêmes binaires.
- Mettre à jour providers, modules et actions via Renovate/Dependabot (PR dédiées avec plan automatique).

### Anti-patterns
| ❌ | Pourquoi | ✅ |
|----|----------|----|
| `apply -auto-approve` après un plan non relu | le plan n'est plus un contrôle | plan sauvegardé + approbation |
| Clés d'accès longue durée en secrets CI | fuite = compromission durable | OIDC |
| Un seul rôle administrateur pour tout | rayon d'explosion maximal | rôles par environnement et par action |
| Re-planifier à l'apply | applique autre chose que ce qui a été relu | `apply tfplan` |
| Pas de verrou/concurrence | deux apply simultanés | `concurrency` + verrou du backend |
| Pipeline unique pour tous les environnements sans garde-fous | un clic peut atteindre la prod | environnements protégés |

### HCP Terraform / Terraform Enterprise : ce que ça apporte
Exécution distante (runs), state managé, RBAC, *variable sets*, politiques (Sentinel/OPA), *cost estimation*, *health assessments* (dérive), registry privée, notifications, intégration VCS. Contrepartie : dépendance à la plateforme et coût par ressource gérée. Pour rester sur des outils open source : Atlantis, ou OpenTofu avec votre CI.

## Exercices
1. Lisez [`solution/terraform-pipeline.yml`](solution/terraform-pipeline.yml). Identifiez : où est l'OIDC ? où est l'approbation ? comment évite-t-on 2 apply simultanés ?
2. Ouvrez la CI **de ce dépôt** : [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml). Que vérifie-t-elle ?
3. Installez `pre-commit` et le fichier `.pre-commit-config.yaml` : committez un fichier mal formaté, observez l'échec.
4. Écrivez un workflow planifié (cron) de détection de dérive qui ouvre une *issue* si `plan -detailed-exitcode` retourne `2`.
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
