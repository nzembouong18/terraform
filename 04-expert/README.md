# 🔴 Niveau 4 — Expert

**Objectif :** concevoir et opérer Terraform **à l'échelle** : multi-comptes/régions, modules de qualité « registry », gouvernance par politiques, et comprendre les internals.

| # | Module | Durée | Vous saurez… |
|---|--------|-------|--------------|
| 14 | [Multi-région & providers avancés](14-multi-region-providers/README.md) | 2 h | alias, `configuration_aliases`, `providers = {}` |
| 15 | [Module de qualité « production »](15-module-qualite/README.md) | 3 h | API de module, sécurité par défaut, tests, exemples, SemVer |
| 16 | [Policy as code](16-policy-as-code/README.md) | 2 h | OPA/Rego sur le plan JSON |
| 17 | [Architecture & échelle (théorie + ateliers)](17-architecture-echelle.md) | 3 h | découpage, Terragrunt/Stacks, drift, perf, internals |
| 18 | [Écrire un provider (introduction)](18-ecrire-un-provider.md) | 2 h | Plugin Framework, protocole, tests d'acceptation |

**Prérequis :** niveaux 1–3. Les labs 14/15 se valident sans compte AWS (`validate`, `terraform test` avec provider simulé) ; un `apply` réel demande un compte (coûts minimes, **pensez au `destroy`**).
