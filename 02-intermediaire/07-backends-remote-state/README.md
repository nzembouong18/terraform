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

## Comprendre en profondeur

### Ce que fait un backend
Un backend est responsable de trois choses : **stocker** le state, le **verrouiller** pendant une opération, et éventuellement **exécuter** les opérations (HCP Terraform). Le bloc `backend` se déclare dans `terraform {}` ; il **n'accepte ni variables ni locals** (il est lu avant leur évaluation) — d'où la *configuration partielle* avec `-backend-config`.

```hcl
terraform {
  backend "s3" {
    bucket       = "acme-tfstate-prod"
    key          = "reseau/terraform.tfstate"     # un chemin par stack
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true                            # verrou natif S3 (≥ 1.10)
  }
}
```

### Bootstrap : l'œuf et la poule
Le bucket qui stocke le state doit exister **avant** la stack qui l'utilise. Approches :
1. **Stack « socle » à state local** (puis migration avec `init -migrate-state`) : simple, mais le premier state doit être mis à l'abri.
2. **Création par script/CLI** (une seule fois) puis gestion Terraform par import.
3. **HCP Terraform / service managé** : aucun bucket à gérer.

Dans tous les cas, ce bucket doit être : **versionné**, **chiffré** (SSE-KMS), **sans accès public**, **journalisé**, avec une politique restrictive (le plus petit nombre de principaux) et idéalement une réplication ou une sauvegarde dans un autre compte.

### Migrer d'un backend à un autre
```bash
# 1. modifier le bloc backend dans le code
terraform init -migrate-state     # propose de copier le state existant vers le nouveau backend
terraform plan                    # doit afficher 0 changement
```
`-reconfigure` ignore l'ancien backend **sans copier** : dangereux si le state n'a pas été sauvegardé. Avant toute migration : `terraform state pull > sauvegarde.tfstate`.

### Verrouillage : comment ça marche
- Avant `plan` (avec refresh) et `apply`, Terraform acquiert un **verrou** (fichier `.tflock` dans S3 avec `use_lockfile`, bail sur un blob Azure, objet GCS…).
- Un second opérateur reçoit « *Error acquiring the state lock* » avec l'ID, l'utilisateur et l'heure du verrou.
- `-lock-timeout=5m` : patienter au lieu d'échouer immédiatement (utile en CI).
- `-lock=false` : **à éviter** (réservé aux cas de lecture seule maîtrisés).
- Verrou orphelin après un job tué : `terraform force-unlock <ID>`, après vérification.

### Partager des données entre stacks
| Technique | Avantages | Inconvénients |
|-----------|-----------|---------------|
| `terraform_remote_state` | simple, typé via les outputs | donne la lecture de **tout** le state ; couplage fort au backend |
| Data sources par tag/nom (`aws_vpc` + `filter`) | découplé, indépendant de l'outil | nécessite des conventions de nommage |
| Paramètres (SSM Parameter Store, Key Vault, Consul…) | contrat explicite, sécurisable finement | un composant de plus |
| Module/registry HCP Terraform (`tfe_outputs`) | outputs seuls, RBAC | lié à HCP Terraform |

Bonne pratique : publier des **outputs stables** (un « contrat ») et considérer leur renommage comme un changement cassant.

### Découper l'infrastructure : où couper ?
Critères pour séparer deux states :
- **Fréquence de changement** : réseau (rare) ≠ application (quotidien).
- **Responsabilité / droits** : l'équipe réseau n'a pas à voir les secrets applicatifs.
- **Rayon d'explosion** : une erreur dans l'app ne doit pas pouvoir détruire le réseau.
- **Durée de plan** : au-delà de quelques minutes, l'équipe cesse de relire les plans.

Découpage typique : `bootstrap` → `réseau` → `données` → `plateforme` → `applications`, avec dépendances **à sens unique** (jamais de cycle entre states).

### Sécurité du backend (check-list)
- [ ] Chiffrement au repos (KMS) et en transit (TLS)
- [ ] Versioning + règle de rétention (restauration)
- [ ] Blocage des accès publics, politique de bucket restrictive
- [ ] Rôles IAM séparés : *lecture* (plan) / *écriture* (apply)
- [ ] Journalisation des accès (CloudTrail / logs d'audit)
- [ ] MFA delete ou verrou d'objets pour la prod
- [ ] Aucune clé d'accès longue durée : OIDC / rôles temporaires

## Exercices
1. Dans `solution/socle`, `apply` (state écrit dans `../etat/socle.tfstate`).
2. Dans `solution/application`, `apply` : le fichier produit mentionne-t-il le nom du cluster ?
3. Changez la valeur du `random_pet` dans `socle` (`-replace`), relancez `application` : propagation ?
4. Ouvrez `backend-s3.tf.example` : listez les protections nécessaires autour du bucket. Écrivez le Terraform qui crée ce bucket (versioning + SSE + public access block) — voir le module [15](../../04-expert/15-module-qualite/README.md).
5. Défi : migrez le backend `local` d'une stack vers un autre chemin avec `init -migrate-state`.

## Corrigé
[`solution/`](solution/)
