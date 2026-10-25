# 17 — Architecture et passage à l'échelle

## 1. Découpage des états (blast radius)
```
00-bootstrap/        # bucket d'état, rôles OIDC (créés une fois, à la main/CLI)
10-reseau/           # VPC, subnets, DNS         ─ change rarement
20-plateforme/       # EKS/ECS, bases de données ─ change parfois
30-applications/     # services                  ─ change souvent
modules/             # modules versionnés
envs/{dev,recette,prod}/
```
Règles : un état **par couche × environnement** ; les couches basses ne dépendent jamais des hautes ; les échanges passent par des **outputs** (remote state, SSM, data sources par tags).

## 2. Orchestration DRY
| Approche | Principe | Quand |
|----------|----------|-------|
| Dossiers + modules | duplication minimale de « glue » | petites/moyennes équipes |
| **Terragrunt** | génère backend/providers, `dependency`, `run-all` | beaucoup d'états/comptes |
| **HCP Terraform Stacks** | déploiements multi-états/régions déclaratifs (`*.tfcomponent.hcl` + `*.tfdeploy.hcl`) | écosystème HCP |
| Workspaces HCP + variable sets | unité = workspace | gouvernance centralisée |
| **OpenTofu** | fork open source compatible (chiffrement du state natif, `for_each` sur providers) | contraintes de licence |

## 3. Dérive et cohérence
- **Détecter** : `plan -detailed-exitcode` planifié ; HCP « health assessments ».
- **Corriger** : par défaut on **ré-applique** le code (source de vérité) ; si le changement manuel est légitime → le coder.
- **Empêcher** : droits en écriture manuels retirés ; SCP/IAM ; politiques.
- `ignore_changes` : uniquement pour les attributs légitimement gérés ailleurs (autoscaling).

## 4. Performance
- `-parallelism=N` (défaut 10) ; attention aux limites d'API (429).
- `-target` : **dépannage uniquement**, jamais un workflow normal (laisse le state incohérent).
- `-refresh=false` pour un plan rapide (au prix de la détection de dérive) ; `-lock-timeout=5m`.
- États trop gros (> 500–1000 ressources) = plans lents → scinder (`moved` + `state mv` / `removed` + `import`).
- Cache de providers : `TF_PLUGIN_CACHE_DIR=~/.terraform.d/plugin-cache`.

## 5. Internals à connaître
- **Walk du graphe** : *plan* → *apply* ; les noeuds : ressources, providers, variables, outputs, modules, « expansion » (count/for_each).
- Valeurs *unknown* (« known after apply ») : propagées dans le plan ; interdites dans `count`/`for_each` clés.
- `terraform graph`, `terraform console`, `TF_LOG=TRACE`.
- Verrou d'état + sérialisation (`serial`, `lineage` dans le state) : détection de conflit d'écriture.
- Le state est un JSON versionné : **ne jamais l'éditer à la main** ; utiliser `state mv/rm`, `moved`, `import`, `removed`.

## 6. Gouvernance et FinOps
- Policies (module 16), `tflint`/`checkov` en CI, tags obligatoires (`default_tags`).
- **Infracost** (estimation de coût dans la PR), budgets, tags de coût.
- Registry privée de modules + SemVer + catalogue « golden paths » (ex. `terraform-aws-web-app`).
- Revue d'**impact** : le plan est le livrable de la PR (commentaire automatique).

## 7. Stratégie de montée de version
1. Lire le *CHANGELOG* et les guides d'upgrade du provider (majeures : 4→5→6).
2. Branche dédiée, `terraform init -upgrade`, plan **sans changement attendu**.
3. Épingler (`~>`) puis avancer progressivement ; automatiser avec Renovate.
4. Terraform core : respecter la compatibilité du state (on ne revient pas en arrière après un apply avec une version plus récente).

## Comprendre en profondeur

### Pourquoi l'échelle change tout
À 20 ressources, un seul état et un seul dossier suffisent. À 2 000 ressources, 10 équipes et 4 comptes, apparaissent : plans de 15 minutes, verrous qui bloquent les équipes, un `apply` qui peut tout détruire, des droits qu'on ne sait plus attribuer, des modules copiés-collés. L'architecture Terraform à l'échelle consiste à **organiser le code, les états, les droits et les flux de livraison** pour que chaque équipe avance sans marcher sur les autres.

### Critères pour découper en états
| Critère | Question à se poser | Exemple |
|---------|--------------------|---------|
| Cycle de vie | Quelle fréquence de changement ? | réseau (mois) vs application (jour) |
| Propriétaire | Quelle équipe est responsable et de garde ? | réseau / plateforme / produit |
| Sensibilité | Qui a le droit de voir et modifier ? | IAM et clés KMS isolés |
| Rayon d'explosion | Si cet `apply` se passe mal, que perd-on ? | une erreur applicative ne doit pas toucher le VPC |
| Taille | Le plan reste-t-il sous quelques minutes ? | scinder au-delà de ~500 ressources |
| Dépendances | Y a-t-il des cycles entre états ? | interdits : toujours du bas vers le haut |

### Communication entre couches
```
00-bootstrap ──► 10-reseau ──► 20-plateforme ──► 30-applications
   (outputs : vpc_id, subnet_ids, zone_dns…)  ──── contrat explicite ────►
```
Le **contrat** entre deux couches = un jeu d'outputs documenté et versionné. Modes de partage : `terraform_remote_state` (simple, couplage fort), data sources par tags (découplé), paramètres/secrets (SSM, Key Vault), ou registry HCP (`tfe_outputs`). Un changement incompatible de contrat est traité comme une version majeure : il se déploie dans l'ordre, couche par couche.

### Gestion des environnements à l'échelle
- **Même code, valeurs différentes** : les modules sont promus d'un environnement à l'autre par version (tag) ; les `tfvars` portent les différences.
- **Promotion progressive** : `dev` → `recette` → `prod`, chaque étape validée par plan + tests.
- **Comptes séparés** par environnement (et par couche sensible) : la meilleure isolation de droits et de coûts.
- Une *landing zone* (AWS Control Tower, Azure Landing Zones, GCP Foundation) fournit le socle : comptes, SCP, journalisation centrale. Terraform la **décrit** au lieu de la créer à la main.

### Orchestration : le problème du « glue code »
Quand on a 40 états, on répète : backend, providers, appels de modules, variables communes. Solutions :
- **Terragrunt** : un `terragrunt.hcl` racine génère backend et provider ; `dependency` déclare l'ordre ; `run-all plan|apply` (commande `run --all` dans les versions récentes) exécute l'ensemble.
  ```hcl
  # terragrunt.hcl racine
  remote_state {
    backend = "s3"
    config  = { bucket = "acme-tfstate", key = "${path_relative_to_include()}/terraform.tfstate", region = "eu-west-3" }
  }
  # envs/prod/reseau/terragrunt.hcl
  include "root" { path = find_in_parent_folders() }
  terraform { source = "git::https://git.acme.io/tf-modules.git//reseau?ref=v2.3.0" }
  inputs = { cidr = "10.10.0.0/16" }
  ```
- **HCP Terraform Stacks** : composants + déploiements déclarés dans `*.tfcomponent.hcl` / `*.tfdeploy.hcl`, orchestration native.
- **Pipelines** avec dépendances `needs:` / matrices par environnement.
- **OpenTofu/CDKTF** : alternatives de langage/outillage selon les contraintes.

### Plateforme interne (golden paths)
Au-delà de 5–10 équipes, ne demandez pas à chacune de maîtriser Terraform à fond :
1. Une **équipe plateforme** publie des **modules « produit »** (`terraform-aws-web-app`, `terraform-aws-postgres`) sécurisés par défaut.
2. Les équipes applicatives **composent** ces modules avec quelques variables.
3. Les garde-fous (policies, tags, quotas) s'appliquent **automatiquement** dans le pipeline.
4. Un portail (Backstage, HCP Terraform no-code modules, Port) expose les modèles en libre-service.
Objectif : vitesse **et** conformité, sans goulot d'étranglement sur l'équipe plateforme.

### Gouvernance : qui peut faire quoi
| Rôle | Peut |
|------|-----|
| Développeur | proposer une PR, lancer un plan (lecture) |
| Relecteur de plateforme | approuver les changements d'infrastructure partagée |
| Pipeline (identité OIDC) | appliquer sur les environnements autorisés |
| Administrateur d'urgence (*break glass*) | accès manuel journalisé, limité dans le temps, post-mortem obligatoire |
| Sécurité | définir les politiques (OPA/SCP) et auditer |

Fichier `CODEOWNERS` : le dossier `10-reseau/` exige l'approbation de l'équipe réseau.

### Observabilité de l'infrastructure-as-code
Mesurez comme un produit : durée de plan/apply, taux d'échec des pipelines, nombre de dérives détectées, âge des versions de providers/modules, couverture de tests, ressources non gérées (inventaire cloud vs états), coûts par tag/projet. Ces indicateurs montrent où investir (scinder un état trop gros, automatiser une correction de dérive).

### Gestion des versions à grande échelle
- Matrice de compatibilité : versions de Terraform/OpenTofu, providers, modules par couche.
- Montées de version **par vagues** : d'abord `dev`, puis les couches peu critiques, enfin la prod.
- Automatisation : Renovate/Dependabot propose les PR ; chaque PR déclenche un plan « sans changement attendu ».
- Politique de dépréciation des modules internes (2 versions majeures supportées, avertissements).
- Ne jamais mélanger deux versions de Terraform sur un même état : une version plus récente peut rendre le state illisible pour une plus ancienne.

### Reprise après sinistre (PRA) de l'IaC
Votre pipeline et vos états sont eux-mêmes une infrastructure critique :
- Sauvegarde et réplication du bucket d'états (autre région/compte), versioning.
- Dépôt Git miroir ; secrets de la CI reconstructibles.
- Procédure documentée et **testée** : « le compte outillage est perdu, comment redéployer ? »
- Code du bootstrap en dehors de la dépendance circulaire (ne pas stocker l'état du bucket d'état dans lui-même sans plan B).

### Anti-patterns à grande échelle
| ❌ | Conséquence |
|----|------------|
| Un état monolithique pour tout | plans lents, verrous permanents, risque maximal |
| Un état par ressource | explosion d'orchestration, dépendances ingérables |
| Copier-coller des environnements | divergence silencieuse |
| Modules maison sans versions | un changement casse tout le monde en même temps |
| `terraform_remote_state` vers n'importe quel état | couplage et fuite de secrets |
| Droits `AdministratorAccess` pour le pipeline | un seul secret compromis = tout compromis |

## Ateliers
1. **Refonte** : partez de [`05-projet-final`](../05-projet-final) et découpez-le en 2 états (`reseau`, `application`) reliés par `terraform_remote_state` ; migrez le state **sans détruire** (`state mv` vers un nouvel état ou `removed`+`import`).
2. **Dérive** : créez un workflow cron qui exécute `plan -detailed-exitcode` et ouvre une issue en cas de dérive.
3. **Terragrunt** : réécrivez `envs/dev` et `envs/prod` avec un `terragrunt.hcl` racine qui génère backend et provider.
4. **Revue d'architecture** : pour 3 équipes, 5 comptes AWS et 3 environnements, proposez le découpage, la stratégie d'identités, le flux de PR et les garde-fous. Justifiez les compromis.
5. **Incident** : le state d'une prod est verrouillé depuis 3 h et un `apply` a été interrompu : décrivez la procédure (vérifier le runner, `force-unlock`, `plan`, réparation des écarts, post-mortem).
