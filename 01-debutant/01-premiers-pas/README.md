# 01 — Premiers pas

## Cours

### Qu'est-ce que Terraform ?
Terraform décrit une infrastructure **de façon déclarative** (« je veux ça ») dans des fichiers `.tf` (langage **HCL**). Il compare l'état **désiré** (code) à l'état **connu** (state) et à la **réalité** (via les APIs des *providers*), puis calcule le plan d'actions.

```
 code .tf ──► terraform plan ──► diff ──► terraform apply ──► API du provider ──► infra réelle
                    ▲                                              │
                    └──────────────── state (.tfstate) ◄───────────┘
```

### Vocabulaire
| Terme | Définition |
|-------|-----------|
| **Provider** | Plugin qui parle à une API (AWS, Azure, GCP, Kubernetes, local, random…) |
| **Resource** | Un objet géré (`resource "type" "nom" {}`) |
| **Data source** | Un objet *lu* sans être géré (`data "type" "nom" {}`) |
| **State** | Fichier JSON qui mappe votre code aux objets réels |
| **Plan** | Liste des actions (`+` créer, `~` modifier, `-` détruire, `-/+` remplacer) |

### Le workflow
```bash
terraform init       # télécharge providers/modules, initialise le backend
terraform fmt        # formate le code
terraform validate   # vérifie la syntaxe et la cohérence interne
terraform plan       # montre ce qui va changer (ne change rien)
terraform apply      # applique (demande confirmation)
terraform destroy    # détruit tout ce que la config gère
```
Fichiers générés : `.terraform/` (plugins, **ne pas versionner**), `.terraform.lock.hcl` (versions des providers, **à versionner** dans un vrai projet), `terraform.tfstate` (**jamais dans git**).

### Anatomie d'un fichier
```hcl
terraform {                        # réglages globaux : version, providers requis
  required_version = ">= 1.6.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}
resource "random_pet" "serveur" {  # type + nom local
  length = 2                       # arguments
}
# référence : <type>.<nom>.<attribut>
output "nom" { value = random_pet.serveur.id }
```
Contraintes de version : `= 1.2.3`, `>= 1.2`, `~> 1.2` (≥ 1.2 et < 2.0), `~> 1.2.3` (≥ 1.2.3 et < 1.3).

### Déclaratif vs impératif : pourquoi c'est important
Un script impératif (Bash, Ansible en mode `command`) décrit **les étapes** : « crée ce serveur, puis ouvre ce port ». Relancé deux fois, il peut créer deux serveurs. Terraform décrit **le résultat attendu** : « il existe un serveur avec ce port ouvert ». Il calcule lui-même les étapes nécessaires à partir de l'état actuel. Conséquences :

- **Idempotence** : appliquer 10 fois la même configuration donne le même résultat (le 2ᵉ `apply` affiche *No changes*).
- **Convergence** : peu importe d'où l'on part (rien, une infra partielle, une infra modifiée à la main), on converge vers l'état décrit.
- **Revue de code** : le diff Git d'un fichier `.tf` est le diff de l'infrastructure.
- **Contrepartie** : on ne contrôle pas l'ordre exact des opérations ; on le déduit en exprimant des **dépendances**.

### Architecture interne : cœur + providers
```
┌────────────────────────┐        gRPC         ┌──────────────────────┐      HTTPS      ┌────────────┐
│  Terraform Core        │ ◄─────────────────► │  Provider (plugin)   │ ◄─────────────► │ API cloud  │
│  - lit le HCL          │                     │  ex. hashicorp/aws   │                 │ (AWS, ...) │
│  - construit le graphe │                     │  - schéma des types  │                 └────────────┘
│  - compare state/code  │                     │  - CRUD des objets   │
└────────────────────────┘                     └──────────────────────┘
```
- Le **cœur** (un binaire unique) ne connaît **aucun** cloud : il gère le langage, le graphe de dépendances, le state et le plan.
- Un **provider** est un binaire séparé, téléchargé par `terraform init` depuis un *registry* (par défaut `registry.terraform.io`). Il décrit le **schéma** des ressources (arguments, attributs) et implémente leurs opérations *Create / Read / Update / Delete*.
- Un provider se nomme `<namespace>/<type>` : `hashicorp/aws`, `hashicorp/random`, `integrations/github`, `cloudflare/cloudflare`. Le nom local (`aws`) sert de préfixe aux ressources (`aws_s3_bucket`).
- Il existe des milliers de providers : IaaS, SaaS, bases de données, DNS, supervision… Tout ce qui a une API peut devenir une ressource Terraform.

### Ce que fait réellement `terraform plan`
1. **Lecture de la configuration** (tous les `*.tf` du dossier, fusionnés — l'ordre des fichiers n'a aucune importance).
2. **Refresh** : pour chaque ressource du state, le provider interroge l'API (*Read*) afin de détecter une **dérive** (modification manuelle).
3. **Construction du graphe** de dépendances à partir des références entre blocs.
4. **Diff** : pour chaque ressource, comparaison *configuration désirée* ↔ *état rafraîchi* → action `create`, `update in-place`, `replace` (détruire + recréer) ou `destroy`.
5. **Affichage** du plan. Aucune écriture dans le monde réel.

`terraform apply` rejoue ce calcul (ou applique un plan sauvegardé : `plan -out=tfplan` puis `apply tfplan`) et exécute les actions en respectant le graphe, puis **écrit le state**.

Lecture des symboles du plan :

| Symbole | Signification | Remarque |
|:-------:|---------------|----------|
| `+` | création | |
| `~` | modification **en place** | pas d'interruption en général |
| `-` | destruction | |
| `-/+` | remplacement (détruire puis créer) | cause : argument « *forces replacement* » modifié |
| `+/-` | remplacement avec `create_before_destroy` | création d'abord |
| `<=` | lecture d'une data source | |
| `(known after apply)` | valeur inconnue avant la création | ex. un ID généré par le cloud |

### Le langage HCL en 5 minutes
HCL (*HashiCorp Configuration Language*) est composé de **blocs**, d'**arguments** et d'**expressions**.

```text
# Commentaire sur une ligne          // également valide
/* Commentaire
   multi-lignes */

<TYPE DE BLOC> "<étiquette 1>" "<étiquette 2>" {   # bloc : type + étiquettes + corps
  argument = expression                             # argument : nom = valeur
  bloc_imbriqué {
    autre_argument = "texte ${var.nom}"             # interpolation dans une chaîne
  }
}
```
Types de blocs principaux :

| Bloc | Rôle | Exemple |
|------|------|---------|
| `terraform` | réglages du cœur (version, providers requis, backend) | `required_version = ">= 1.6"` |
| `provider` | configuration d'un provider (région, credentials…) | `provider "aws" { region = "eu-west-3" }` |
| `resource` | objet **géré** | `resource "aws_s3_bucket" "logs" {}` |
| `data` | objet **lu** | `data "aws_caller_identity" "moi" {}` |
| `variable` | entrée | voir module 02 |
| `locals` | valeurs calculées | voir module 02 |
| `output` | sortie | voir module 02 |
| `module` | appel d'un module | voir module 06 |

Types de valeurs : chaînes (`"abc"`), nombres (`42`), booléens (`true`), listes (`["a", "b"]`), maps/objets (`{ cle = "val" }`). Une chaîne multi-lignes utilise le *heredoc* (`<<-EOT … EOT`).

> **Ordre des fichiers = sans importance.** Terraform lit tous les `.tf` du dossier comme un seul document. La convention (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `providers.tf`) n'est là que pour la lisibilité.

### Organiser un dossier de travail
```
mon-projet/
├── versions.tf        # terraform { required_version, required_providers }
├── providers.tf       # blocs provider
├── main.tf            # ressources
├── variables.tf       # entrées
├── outputs.tf         # sorties
├── terraform.tfvars   # valeurs des variables (jamais de secrets ici si versionné)
├── .terraform/        # (généré) plugins et modules téléchargés   → .gitignore
├── .terraform.lock.hcl# (généré) verrou des versions de providers → à versionner
└── terraform.tfstate  # (généré) état local                       → .gitignore
```
Un dossier = un **module racine** = un **state**. Deux dossiers différents sont deux infrastructures indépendantes.

### Cycle de vie d'un provider : le lock file
`terraform init` choisit, pour chaque provider, **la plus haute version compatible** avec les contraintes, puis l'enregistre avec ses *hash* dans `.terraform.lock.hcl`. Ensuite, tous les collègues et la CI utilisent **exactement** cette version. Pour monter de version volontairement : `terraform init -upgrade`, puis relire le diff du lock file en revue de code.

### Déboguer : outils de base
```bash
terraform console                    # REPL pour tester des expressions
terraform validate                   # erreurs de syntaxe / de références
terraform fmt -recursive -check      # contrôle de formatage (échoue en CI si non formaté)
TF_LOG=DEBUG terraform plan 2> debug.log   # logs détaillés (TRACE, DEBUG, INFO, WARN, ERROR)
terraform plan -out=tfplan && terraform show tfplan    # relire un plan sauvegardé
terraform show -json tfplan | jq .   # plan lisible par des machines (policy as code)
```

### Terraform et ses alternatives
| Outil | Approche | Remarque |
|-------|----------|----------|
| **Terraform / OpenTofu** | déclaratif, multi-cloud, state | standard de fait pour le provisioning |
| CloudFormation / Bicep / Deployment Manager | déclaratif, **un seul cloud** | intégration native, pas de state à gérer |
| Pulumi / CDK | déclaratif via un langage généraliste (TypeScript, Python…) | boucles et tests « natifs » ; plus de liberté, plus de risque |
| Ansible | procédural / idempotent | excellent pour la **configuration** des serveurs, moins pour le cycle de vie cloud |
| Crossplane | déclaratif via Kubernetes (CRD) | contrôleurs en boucle continue |

Terraform **provisionne** (crée serveurs, réseaux, DNS…) ; Ansible/cloud-init **configurent** l'intérieur des machines ; Packer **fabrique** les images. Ces outils se complètent.

### Erreurs fréquentes du débutant
- Oublier `terraform init` après avoir ajouté un provider ou un module (« *Inconsistent dependency lock file* », « *Module not installed* »).
- Modifier un nom de ressource en pensant « renommer » : Terraform comprend détruire + créer (voir module 11).
- Supprimer `terraform.tfstate` pour « repartir de zéro » : les ressources réelles existent toujours mais Terraform les a oubliées.
- Committer `.terraform/` (binaires de plusieurs centaines de Mo) ou le state (secrets).
- Lancer `apply -auto-approve` par habitude, sans avoir lu le plan.

## Exercices

1. **Hello Terraform** — dans `exercice/main.tf`, déclarez `random_pet` et un `local_file` dont le contenu contient le nom généré. Lancez `init`, `plan`, `apply`. Ouvrez `out/bienvenue.txt`.
2. **Lire le plan** — relancez `plan` : que dit-il ? (*No changes*). Puis changez `length = 3` : quels symboles voyez-vous ? Pourquoi `-/+` (*forces replacement*) ?
3. **Dérive (drift)** — modifiez à la main `out/bienvenue.txt`, relancez `plan`. Que fait Terraform ? (avec le provider `local`, il annonce que le fichier `will be created` : un contenu différent ne correspond plus à la ressource suivie.) Appliquez, puis recommencez en **supprimant** le fichier et en lançant `terraform plan -refresh-only` : que signifie « has been deleted » ?
4. **Exploration** — `terraform show`, `terraform output`, `terraform state list`, `terraform graph | dot -Tpng > g.png` (si Graphviz).
5. **Nettoyage** — `terraform destroy`. Le fichier a-t-il disparu ?

## Questions de compréhension
- Pourquoi `random_pet` ne change-t-il pas à chaque `apply` ?
- Quelle différence entre `plan` et `apply` ? Que se passe-t-il si on supprime le state ?
- À quoi sert `.terraform.lock.hcl` ?

<details><summary>Réponses</summary>

- La valeur est stockée dans le **state** ; elle ne change que si un argument « force replacement » change.
- `plan` calcule seulement ; `apply` exécute. Sans state, Terraform ne connaît plus ses ressources et voudra tout recréer (doublons dans le cloud !).
- Il fige les versions exactes (et hash) des providers pour des builds reproductibles.
</details>

## Corrigé
[`solution/main.tf`](solution/main.tf) — `cd solution && terraform init && terraform apply`.
