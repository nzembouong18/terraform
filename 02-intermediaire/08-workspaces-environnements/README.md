# 08 — Workspaces et environnements

Deux stratégies pour dev/recette/prod :

| | Workspaces CLI | Dossiers/états séparés (recommandé en prod) |
|--|----------------|----------------|
| Code | identique | un dossier `envs/<env>` qui appelle les mêmes modules |
| State | `terraform.tfstate.d/<ws>` (même backend) | backend/clé distincts, voire comptes distincts |
| Isolation | faible (même credentials) | forte (IAM, comptes séparés) |
| Divergences d'env | via `terraform.workspace` (conditionnel) | via variables et appels de modules |

> Les *workspaces CLI* ne sont **pas** un outil d'isolation de sécurité. Ils conviennent aux environnements éphémères (branches de feature) ; pour la prod, préférez des états/comptes séparés. (Ne pas confondre avec les « workspaces » de HCP Terraform, qui sont des unités d'état + variables + permissions.)

## Commandes
```bash
terraform workspace list | new prod | select prod | show | delete prod
terraform plan -var-file=envs/prod.tfvars
```

## Comprendre en profondeur

### Ce que sont réellement les workspaces CLI
Un workspace est **un state supplémentaire** associé à la même configuration et au même backend. Le workspace `default` existe toujours et ne peut pas être supprimé. Avec le backend local, les states vivent dans `terraform.tfstate.d/<workspace>/` ; avec S3, sous `env:/<workspace>/<key>`. La valeur courante est disponible via `terraform.workspace`.

```hcl
locals {
  config = {
    default = { taille = "small", replicas = 1 }
    prod    = { taille = "large", replicas = 3 }
  }
  courant = lookup(local.config, terraform.workspace, local.config["default"])
}
```

**Limites** :
- mêmes identifiants pour tous les workspaces → un opérateur en `dev` peut faire `workspace select prod` par erreur et détruire la prod ;
- le workspace actif est **invisible** dans le code et dans la ligne de commande : source classique d'erreurs ;
- les différences entre environnements se codent par des conditions, ce qui rend le code illisible à mesure qu'il grandit.

### Dossiers par environnement : la structure recommandée
```
infra/
├── modules/                  # code réutilisable, versionné
│   ├── reseau/
│   └── application/
└── envs/
    ├── dev/    { main.tf, backend.hcl, terraform.tfvars }   # appelle les modules (source = "../../modules/…")
    ├── recette/
    └── prod/
```
Chaque dossier a **son backend, son state, ses variables et ses credentials**. Les différences entre environnements sont explicites (valeurs des variables), et la promotion consiste à propager une **version de module** (tag) de `dev` vers `prod`.

### Variante : un seul code, plusieurs fichiers de variables
```bash
terraform init   -backend-config=envs/prod.backend.hcl -reconfigure
terraform plan   -var-file=envs/prod.tfvars
```
Plus simple (aucune duplication de code racine), mais l'isolation dépend de la rigueur des commandes. Utilisez-la avec une CI qui impose le couple *backend + tfvars* par environnement.

### Comparatif des stratégies
| Critère | Workspaces CLI | `-var-file` + backends distincts | Dossiers `envs/` | Comptes cloud séparés |
|---------|:---:|:---:|:---:|:---:|
| Duplication de code | aucune | aucune | faible (appels de modules) | selon le choix |
| Isolation du state | moyenne | bonne | bonne | **très bonne** |
| Isolation des droits | ❌ | ✅ si credentials distincts | ✅ | ✅✅ |
| Lisibilité des écarts | ❌ (conditions) | ✅ (tfvars) | ✅✅ | ✅ |
| Environnements éphémères (PR) | ✅✅ | ✅ | ⚠️ | ⚠️ |
| Recommandé pour la prod | non | oui | **oui** | **oui** (réglementé) |

### Environnements éphémères
Pour tester une branche, un workspace nommé d'après la branche (`terraform workspace new pr-123`) permet de créer une infra jetable, puis `terraform destroy` + `workspace delete` à la fermeture de la PR. Automatisez ce nettoyage (CI + budget d'alerte) pour éviter les coûts fantômes.

### Réduire les écarts entre environnements
- Mêmes **modules**, mêmes **versions** ; seuls changent la taille, le nombre de réplicas, les noms et les CIDR.
- Éviter que `prod` ait des ressources que `dev` n'a pas : on ne teste alors jamais ce qui part en prod.
- Les différences volontaires (haute disponibilité, sauvegardes) se pilotent par des variables booléennes explicites, **documentées**.
- Valider chaque module avec `terraform test` (module 10) avant de le promouvoir.

### HCP Terraform : le mot « workspace » ne veut pas dire la même chose
Dans HCP Terraform, un workspace regroupe **state + variables + permissions + historique des runs** pour une stack. C'est l'équivalent d'un dossier d'environnement, pas d'un workspace CLI. Les *variable sets* partagent des variables entre workspaces, les *projects* regroupent des workspaces pour le RBAC.

## Exercices
1. Dans `solution/`, appliquez dans `default`, puis créez le workspace `prod` : le contenu de `out/` change-t-il ? Où est le state de chaque workspace ?
2. Utilisez la variable `environnement` à la place du workspace : `-var-file=envs/dev.tfvars`.
3. Ajoutez un environnement `recette` dans la map `config`.
4. Que se passe-t-il avec `terraform.workspace` inconnu dans la map ? Utilisez `lookup(..., défaut)` pour être robuste.
5. Discussion : pour une prod réglementée, pourquoi préférer un compte/état séparé ? Dessinez l'arborescence `envs/{dev,prod}` du [projet final](../../05-projet-final/README.md).

## Corrigé
[`solution/`](solution/)
