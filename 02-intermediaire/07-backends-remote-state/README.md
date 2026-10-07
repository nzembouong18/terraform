# 07 — Backends et remote state

## Pourquoi un backend distant ?
Le state local ne convient pas à une équipe : pas de partage, pas de verrou, risque de perte, secrets sur un poste. Un **backend** définit *où* le state est stocké.

| Backend | Verrouillage | Remarques |
|---------|--------------|-----------|
| `local` | fichier | dev/labs uniquement |
| `s3` | `use_lockfile = true` (natif, ≥ 1.10) ; ancien : table DynamoDB (dépréciée) | activer versioning + chiffrement + blocage public |
| `azurerm` | lease sur le blob | |
| `gcs` | natif | |
| `remote` / `cloud` (HCP Terraform) | natif | state, runs, RBAC, policies hébergés |

## Configuration partielle
Ne mettez pas de valeurs d'environnement en dur ; passez-les à l'init :
```bash
terraform init -backend-config=backend.hcl
terraform init -migrate-state      # après changement de backend : copie le state existant
terraform init -reconfigure        # ignore l'ancienne config
```

## Lire l'état d'une autre stack
`data "terraform_remote_state"` lit **uniquement les outputs** d'un autre state. ⚠️ Cela donne un accès en lecture à tout ce state. Alternatives plus découplées : data sources du provider (par tags), SSM Parameter Store, registry HCP.

## Bonnes pratiques de découpage
- 1 state **par couche et par environnement** (réseau, données, applicatif) : rayon d'explosion réduit, plans rapides.
- Ne pas faire un « monolithe » de 2 000 ressources.
- Bucket d'état dans un compte **dédié**, accès restreint, **versioning activé** (restauration), journalisation.

## Exercices
1. Dans `solution/socle`, `apply` (state écrit dans `../etat/socle.tfstate`).
2. Dans `solution/application`, `apply` : le fichier produit mentionne-t-il le nom du cluster ?
3. Changez la valeur du `random_pet` dans `socle` (`-replace`), relancez `application` : propagation ?
4. Ouvrez `backend-s3.tf.example` : listez les protections nécessaires autour du bucket. Écrivez le Terraform qui crée ce bucket (versioning + SSE + public access block) — voir le module [15](../../04-expert/15-module-qualite/README.md).
5. Défi : migrez le backend `local` d'une stack vers un autre chemin avec `init -migrate-state`.

## Corrigé
[`solution/`](solution/)
