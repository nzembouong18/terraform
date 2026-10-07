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
