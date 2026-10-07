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

## Exercices
1. Dans `solution/`, appliquez dans `default`, puis créez le workspace `prod` : le contenu de `out/` change-t-il ? Où est le state de chaque workspace ?
2. Utilisez la variable `environnement` à la place du workspace : `-var-file=envs/dev.tfvars`.
3. Ajoutez un environnement `recette` dans la map `config`.
4. Que se passe-t-il avec `terraform.workspace` inconnu dans la map ? Utilisez `lookup(..., défaut)` pour être robuste.
5. Discussion : pour une prod réglementée, pourquoi préférer un compte/état séparé ? Dessinez l'arborescence `envs/{dev,prod}` du [projet final](../../05-projet-final/README.md).

## Corrigé
[`solution/`](solution/)
