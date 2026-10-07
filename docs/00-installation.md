# Installation et prise en main de l'environnement

## Terraform
| OS | Commande |
|----|----------|
| macOS | `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` |
| Windows | `winget install Hashicorp.Terraform` (ou `choco install terraform`) |
| Linux (Debian/Ubuntu) | dépôt APT HashiCorp : <https://developer.hashicorp.com/terraform/install> |
| Tous | binaire zip depuis <https://releases.hashicorp.com/terraform/> ; gestionnaire de versions **tfenv** / **mise** / **asdf** recommandé |

```bash
terraform version          # ≥ 1.7 requis pour tous les labs (1.9+ conseillé)
terraform -install-autocomplete
```
> **OpenTofu** (`tofu`) est compatible avec la majorité des labs (remplacez `terraform` par `tofu`). Voir [07-ecosysteme.md](07-ecosysteme.md).

## Outils complémentaires (optionnels mais recommandés)
| Outil | Usage | Installation |
|-------|-------|--------------|
| `tflint` | lint | `brew install tflint` |
| `checkov` ou `trivy` | sécurité statique | `pipx install checkov` |
| `terraform-docs` | doc des modules | `brew install terraform-docs` |
| `pre-commit` | hooks git | `pipx install pre-commit` |
| `opa` | politiques (module 16) | <https://www.openpolicyagent.org/docs/latest/#running-opa> |
| `jq` | lire les JSON de plan/state | gestionnaire de paquets |
| Graphviz | `terraform graph \| dot -Tpng` | gestionnaire de paquets |
| AWS CLI | labs cloud (niveaux 4+/projet) | <https://aws.amazon.com/cli/> |

## Éditeur
VS Code + extension **HashiCorp Terraform** (autocomplétion, `fmt` à l'enregistrement). Dans `settings.json` : `"[terraform]": { "editor.formatOnSave": true }`.

## Compte cloud (uniquement pour les modules 14, 15 réels et le projet final)
- Compte AWS dédié à la formation, **budget d'alerte** (AWS Budgets, 5 €), utilisateur IAM/SSO à droits limités, **pas de clés root**.
- `aws configure sso` (préféré) ou variables `AWS_PROFILE`.
- Toujours `terraform destroy` en fin de séance.

## Environnement reproductible en conteneur
```bash
docker run --rm -it -v "$PWD":/work -w /work hashicorp/terraform:1.9 version
```

## Variables d'environnement utiles
| Variable | Rôle |
|----------|------|
| `TF_LOG`, `TF_LOG_PATH` | logs de debug |
| `TF_VAR_<nom>` | fournir une variable |
| `TF_IN_AUTOMATION=1` | sorties adaptées à la CI |
| `TF_PLUGIN_CACHE_DIR` | cache partagé des providers |
| `TF_CLI_ARGS_plan="-parallelism=20"` | options par défaut |

## Vérifier votre installation
```bash
git clone <ce dépôt> && cd terraform
./scripts/validate-all.sh --fast       # fmt + validate de tous les labs (accès au registry requis)
./scripts/validate-all.sh              # + apply/destroy hors-ligne + tests (≈ 2 min)
```
