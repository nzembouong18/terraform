# 06 — Modules

Un **module** = un dossier de `.tf`. Le dossier où vous lancez `terraform` est le **module racine** ; il appelle des **modules enfants**.

## Structure recommandée
```
modules/mon-module/
├── main.tf        # ressources
├── variables.tf   # entrées (avec description + type + validation)
├── outputs.tf     # sorties
├── versions.tf    # required_version + required_providers (bornes, sans config)
└── README.md      # usage (terraform-docs peut le générer)
```

## Appeler un module
```hcl
module "web" {
  source  = "./modules/fichier-config"   # local
  # source  = "terraform-aws-modules/vpc/aws"   + version = "~> 5.0"   # registry
  # source  = "git::https://github.com/org/repo.git//sous/dossier?ref=v1.2.0"   # git, TOUJOURS épinglé
  nom = "web"
}
# lecture d'une sortie : module.web.chemin
```
`count`/`for_each` fonctionnent aussi sur les modules (≥ 0.13).

## Principes de conception
1. **Une responsabilité** par module (réseau, base de données…), pas un « module fourre-tout ».
2. **Peu de variables obligatoires**, valeurs par défaut *sûres*.
3. **Pas de `provider` configuré dans un module** : seul le racine configure ; le module déclare ce dont il a besoin.
4. **Outputs** pour tout ce dont un consommateur pourrait avoir besoin (id, arn).
5. **Composition > héritage** : le racine assemble des modules (`reseau` → `application`) en passant les outputs.
6. Versionnez (tags git SemVer) et documentez ; modifier une variable = changement potentiellement cassant.

## Comprendre en profondeur

### Pourquoi des modules ?
- **Réutilisation** : écrire une fois, instancier N fois (un réseau par environnement).
- **Abstraction** : le consommateur manipule 5 variables au lieu de 40 ressources.
- **Standardisation** : l'entreprise impose ses bonnes pratiques (chiffrement, tags, journalisation) *dans* le module.
- **Testabilité et versionnement** : un module a son propre cycle de vie (SemVer, tests, changelog).

Un module n'est pas toujours nécessaire : si vous l'appelez une seule fois et qu'il ne fait que renommer une ressource sans ajouter de valeur, il **alourdit** le code. Un bon module encapsule une **décision d'architecture** (par exemple « un bucket conforme à notre politique »).

### Portée et interface d'un module
Un module est une **boîte noire** : seules ses `variable` entrent, seuls ses `output` sortent. Il ne peut pas lire les ressources du parent, et le parent ne peut pas lire les ressources internes — uniquement les outputs.
```
module racine ──variables──► module enfant ──outputs──► module racine
```
```hcl
# modules/reseau/outputs.tf
output "subnet_ids" { value = [for s in aws_subnet.prive : s.id] }
# racine
module "reseau"     { source = "./modules/reseau" }
module "application" {
  source     = "./modules/application"
  subnet_ids = module.reseau.subnet_ids     # composition par les outputs
}
```

### Sources de modules
| Source | Syntaxe | Remarque |
|--------|---------|----------|
| Chemin local | `./modules/x` | pas de version, mêmes dépôt/cycle |
| Registry public | `terraform-aws-modules/vpc/aws` + `version = "~> 5.0"` | vérifier l'éditeur, la maintenance, la licence |
| Registry privée | `app.terraform.io/org/vpc/aws` | contrôle et gouvernance |
| Git | `git::https://…/repo.git//sous/dossier?ref=v1.2.0` | épingler un **tag** ou un commit |
| S3/GCS/HTTP | archive | cas particuliers |

`terraform init` télécharge les modules dans `.terraform/modules/`. Après tout changement de `source` ou de `version` : relancer `init` (ou `init -upgrade`).

### Conception des variables d'un module
- **Peu d'obligatoires**, bonnes valeurs par défaut sûres (chiffrement activé, accès public bloqué).
- **Types stricts** + `validation` : le module échoue tôt, avec un message clair.
- Préférez des `object` à des dizaines de variables plates, et `optional()` pour les réglages avancés.
- Évitez les « interrupteurs » à rallonge (`create_x`, `enable_y`, `enable_z`…) : signe que le module fait trop de choses.
- Ne **jamais** coder en dur un nom global unique (bucket) : exposez-le en variable ou dérivez-le d'un préfixe.

### Modules et providers
Un module **déclare** ses besoins dans `required_providers`, mais ne **configure** pas le provider (région, credentials). Si le module doit utiliser plusieurs configurations (ex. deux régions), le parent passe des alias :
```hcl
module "replica" {
  source    = "./modules/bucket"
  providers = { aws = aws.paris, aws.replica = aws.irlande }
}
```
Un module qui contient son propre bloc `provider` ne peut plus être utilisé avec `count`/`for_each`/`depends_on` ni être supprimé proprement (voir module 14).

### Multiplier un module
```hcl
module "services" {
  for_each = var.services              # map(object)
  source   = "./modules/service"
  nom      = each.key
  image    = each.value.image
}
# adresses : module.services["api"].aws_ecs_service.this
# sorties  : module.services["api"].url   ou   { for k, m in module.services : k => m.url }
```

### Versionner et faire évoluer un module
- **SemVer** : `MAJOR` = changement cassant (variable renommée/supprimée, ressource recréée), `MINOR` = fonctionnalité compatible, `PATCH` = correctif.
- Un changement qui **recrée** des ressources est cassant même si les variables ne changent pas : documentez-le et fournissez des blocs `moved` à l'intérieur du module.
- Ajouter une variable avec un `default` qui préserve le comportement est un changement **compatible**.
- Générez le README avec `terraform-docs markdown table .` pour garder les entrées/sorties à jour.

### Anti-patterns
| ❌ Anti-pattern | Pourquoi | ✅ Alternative |
|-----------------|----------|---------------|
| Module « fourre-tout » (VPC + BDD + app) | rayon d'explosion énorme, non réutilisable | un module par responsabilité |
| *Wrapper* qui recopie 1 ressource et toutes ses variables | indirection sans valeur | utiliser la ressource directement |
| Module qui lit des `data` du parent par convention de nommage | couplage caché | passer l'information en variable |
| Source Git sans `?ref=` | le code change sans prévenir | tag ou SHA |
| `depends_on` sur un module entier | plan opaque (tout *known after apply*) | dépendances via outputs |
| Sorties qui renvoient des objets entiers de ressources | expose et fige les détails internes | ne sortir que ce qui est utile |

### Structure standard d'un dépôt de module (registry)
```
terraform-<PROVIDER>-<NOM>/
├── main.tf  variables.tf  outputs.tf  versions.tf  README.md  LICENSE
├── examples/minimal/    examples/complet/    # exemples exécutables = documentation + tests
└── tests/               *.tftest.hcl
```
Voir le module [15](../../04-expert/15-module-qualite/README.md) pour le détail de la qualité attendue.

## Exercices
1. Lisez `solution/modules/fichier-config`. Appelez-le une fois, puis 3 fois avec `for_each`.
2. Ajoutez une variable `proprietaire` avec validation et un output `empreinte`.
3. Listez les adresses créées (`terraform state list`) : repérez le préfixe `module.services["api"]`.
4. Ajoutez un 2e module `module "lecteur"` qui consomme la sortie `chemin` du premier (composition).
5. Défi : extraire une partie de votre code racine vers un module **sans détruire** (`moved` — voir module 11).

## Corrigé
[`solution/`](solution/)
