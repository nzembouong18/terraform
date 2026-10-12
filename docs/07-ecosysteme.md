# Écosystème et alternatives

## Licence et OpenTofu
Depuis la version 1.6 (août 2023), Terraform est distribué sous licence **BUSL** (source-available) au lieu de MPL 2.0. En réaction, la communauté a créé **OpenTofu** (Linux Foundation, licence MPL 2.0), fork de Terraform 1.5 : même langage HCL, mêmes providers (registry compatible), CLI `tofu`. OpenTofu a ajouté des fonctionnalités propres (chiffrement natif du state, `for_each` sur providers, etc.), tandis que Terraform en a d'autres (Stacks HCP, ephemeral/write-only côté HashiCorp).
**Conséquence pratique** : ce parcours reste valable pour les deux ; vérifiez la compatibilité des fonctionnalités récentes (≥ 1.8) avant de basculer. Consultez les pages officielles pour l'état actuel de chaque projet.

## Outils autour de Terraform
| Catégorie | Outils |
|-----------|--------|
| Orchestration | Terragrunt, HCP Terraform (+ Stacks), Atlantis, Spacelift, env0, Scalr |
| Qualité | tflint, terraform-docs, pre-commit-terraform |
| Sécurité | checkov, trivy, tfsec (intégré à trivy), gitleaks, detect-secrets |
| Politiques | OPA/Conftest, Sentinel |
| Tests | `terraform test`, Terratest (Go), kitchen-terraform |
| Coûts | Infracost |
| Visualisation | Rover, Blast Radius, `terraform graph` |
| Mises à jour | Renovate, Dependabot |
| Import/rétro-ingénierie | `import` + `-generate-config-out`, Terraformer (communautaire), AWS Cloud Control provider |

## Terraform vs autres IaC
| Outil | Approche | Quand l'envisager |
|-------|----------|-------------------|
| CloudFormation / Bicep / Deployment Manager | natif d'un cloud | 100 % mono-cloud, intégration profonde |
| Pulumi / CDK for Terraform | vrais langages (TS, Python, Go) | équipes dev, logique complexe |
| Crossplane | Kubernetes comme plan de contrôle | plateforme interne K8s-native |
| Ansible | procédural, configuration de serveurs | configuration OS (complémentaire à Terraform) |

Terraform provisionne (**infrastructure**), Ansible/cloud-init/Packer **configurent** ou **construisent des images** ; les deux se combinent.

## Comprendre en profondeur

### Choisir entre Terraform et OpenTofu
| Critère | Terraform (HashiCorp/IBM) | OpenTofu |
|---------|--------------------------|----------|
| Licence | BUSL 1.1 (source-available) | MPL 2.0 (open source) |
| Gouvernance | éditeur unique | Linux Foundation, comité technique |
| Compatibilité des providers | registry HashiCorp | registry OpenTofu, quasi 100 % compatible |
| Fonctions propres | HCP Terraform, Stacks, ephemeral/write-only, `terraform test` natif | chiffrement natif du state, `for_each` sur providers, early evaluation des variables dans les backends |
| Support commercial | HashiCorp/IBM | écosystème (Spacelift, env0, Scalr, Gruntwork…) |
| Migration | — | `tofu init` suffit souvent ; relire les écarts de versions |

À considérer : contraintes juridiques de la licence, dépendance à HCP Terraform, besoin de fonctions spécifiques, politique d'achat de l'entreprise. Les deux outils partagent 95 % du langage : le parcours s'applique à l'un comme à l'autre ; **vérifiez la compatibilité** avant d'adopter une fonctionnalité récente.

### Plateformes d'exécution
| Plateforme | Positionnement | À retenir |
|------------|----------------|-----------|
| **HCP Terraform / TFE** | plateforme HashiCorp | state, RBAC, policies Sentinel/OPA, dérive, registry privée |
| **Atlantis** | open source, auto-hébergé | commentaires de PR (`atlantis plan`/`apply`), simple et efficace |
| **Spacelift / env0 / Scalr** | plateformes tierces multi-outils | politiques OPA, workflows personnalisables, support OpenTofu |
| **GitHub Actions / GitLab CI** | pipelines génériques | maximum de flexibilité, garde-fous à écrire soi-même |
| **Terraform Cloud Agents / runners** | exécution dans votre réseau | accès à des ressources privées |

### Terragrunt, CDKTF, Pulumi : à quoi servent-ils ?
- **Terragrunt** : *wrapper* Terraform/OpenTofu pour éviter la répétition (backend, providers), exprimer des dépendances entre états, exécuter `run-all`. Idéal pour de nombreux états homogènes.
- **CDK for Terraform (CDKTF)** : décrire l'infrastructure en TypeScript/Python/Go qui génère du JSON Terraform. Les atouts : boucles, abstractions, tests unitaires. Les risques : débogage via le code généré, un second langage à maintenir. Le projet connaît des évolutions de gouvernance : vérifier son état avant adoption.
- **Pulumi** : moteur propre (state séparé), langages généralistes, ressources similaires via bridges de providers Terraform.
- **Crossplane** : plan de contrôle Kubernetes qui réconcilie en continu des ressources cloud ; adapté à une plateforme interne centrée Kubernetes.

### Fournir un contexte de coût et de qualité
- **Infracost** : estimation du coût d'un plan dans la PR, budgets et alertes sur la dérive de coût.
- **terraform-docs** : documentation des modules, synchronisée au commit.
- **tflint** + règles par provider (AWS, Azure, GCP) : détecte les valeurs invalides avant l'API (type d'instance inexistant).
- **pre-commit-terraform** : regroupe fmt, validate, docs, tflint, checkov dans un hook.
- **Rover / Blast Radius / Inframap** : visualisation de graphes d'infrastructure.

### Conseils pour construire sa « boîte à outils »
1. Commencer minimal : `fmt`, `validate`, `tflint`, `checkov`, `terraform test`, CI avec plan en PR.
2. Ajouter les **politiques** (OPA) quand les premières règles d'entreprise émergent.
3. Introduire **Terragrunt/Stacks** seulement quand la répétition devient réellement douloureuse.
4. Mesurer : durée des plans, dérives, taux d'échec, coûts.
5. Documenter les choix (ADR) pour que l'équipe comprenne **pourquoi** ces outils.

### Veille et communauté
Notes de version Terraform/OpenTofu et providers, forums officiels, HashiConf, revues de code de modules populaires (`terraform-aws-modules`), Cloud Posse, Gruntwork. Lire le **CHANGELOG** de chaque montée de version majeure de provider avant d'appliquer.
