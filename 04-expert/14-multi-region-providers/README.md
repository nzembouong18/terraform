# 14 — Multi-région et configuration avancée des providers

## Alias de provider
Plusieurs configurations d'un même provider (région, compte, cluster) :
```hcl
provider "aws" { region = "eu-west-3" }                    # configuration par défaut
provider "aws" { alias = "us"  region = "us-east-1" }      # configuration alias

resource "aws_s3_bucket" "x" { provider = aws.us  bucket = "..." }
```

## Passer les providers à un module
```hcl
module "donnees" {
  source    = "./modules/bucket-replique"
  providers = { aws = aws, aws.replica = aws.replica }     # clé = nom côté module
}
```
Le module doit **déclarer** les alias attendus :
```hcl
required_providers { aws = { source = "hashicorp/aws"  configuration_aliases = [aws.replica] } }
```

## Multi-compte
```hcl
provider "aws" {
  alias  = "prod"
  region = "eu-west-3"
  assume_role { role_arn = "arn:aws:iam::222222222222:role/terraform" }
}
```
Pattern : un compte « outillage » assume des rôles dans les comptes cibles.

## Limites à connaître
- **Pas de `for_each` sur les providers** : une configuration par alias, écrite explicitement (ou générée par du tooling : Terragrunt, Stacks HCP Terraform).
- Un provider ne doit pas dépendre d'une ressource créée dans le même état (ex. config Kubernetes dépendant d'un cluster créé en même temps) → séparer en deux états/couches.
- Un module **ne configure pas** de provider : sinon suppression du module impossible (provider disparu avant la destruction).
- `default_tags` (AWS) : tags appliqués automatiquement à toutes les ressources.

## Fonctions fournies par les providers (≥ 1.8)
`provider::aws::arn_parse(...)`, `provider::time::rfc3339_parse(...)` : fonctions pures déclarées par les providers.

## Comprendre en profondeur

### Comment Terraform choisit un provider pour une ressource
1. Si la ressource a `provider = aws.alias`, c'est cette configuration.
2. Sinon, la configuration **par défaut** (le bloc `provider "aws"` sans `alias`) du module où elle est déclarée.
3. Sinon, si aucun bloc n'existe, une configuration vide implicite (les credentials viennent alors de l'environnement).

Le préfixe du type fait le lien : `aws_s3_bucket` → provider local `aws`. Le **nom local** d'un provider peut différer de sa source : `required_providers { aws_us = { source = "hashicorp/aws" } }` est possible mais déroutant ; gardez le nom canonique.

### Cas d'usage des alias
| Besoin | Exemple |
|--------|---------|
| Multi-région | bucket principal à Paris + réplique à Francfort ; certificat ACM obligatoire en `us-east-1` pour CloudFront |
| Multi-compte | un compte « outillage » déploie dans les comptes `dev`, `prod`, `sécurité` |
| Multi-cluster | plusieurs providers `kubernetes`/`helm` pointant vers des clusters distincts |
| Multi-instance de SaaS | deux organisations GitHub, deux comptes Datadog |
| Provider de secours | région de reprise (PRA) déclarée à côté de la région active |

### Passer les providers aux modules : les trois formes
```hcl
# 1. Héritage implicite : le module utilise le provider par défaut du parent.
module "a" { source = "./a" }

# 2. Passage explicite d'un provider par défaut ou alias.
module "b" {
  source    = "./b"
  providers = { aws = aws.us }               # le module croit utiliser « aws »
}

# 3. Passage de plusieurs configurations (le module déclare configuration_aliases).
module "c" {
  source    = "./c"
  providers = { aws = aws, aws.replica = aws.replica }
}
```
Dans la forme 3, le module écrit `provider = aws.replica` sur ses ressources, sans savoir de quelle région il s'agit : c'est le parent qui décide. Cela rend le module **réutilisable dans n'importe quel couple de régions/comptes**.

### Configurer un provider à partir d'une autre ressource : le piège
```hcl
# ❌ À éviter dans le MÊME état
resource "aws_eks_cluster" "c" { … }
provider "kubernetes" {
  host = aws_eks_cluster.c.endpoint          # inconnu au premier plan
}
```
Au premier `plan`, l'endpoint n'existe pas : le provider ne peut pas être configuré, et à la destruction le provider peut disparaître avant les ressources qu'il gère. Solution : **deux états** (couche « cluster », puis couche « workloads » qui lit l'endpoint via data source ou remote state), ou deux étapes de déploiement ordonnées.

### Multi-compte : trois schémas
| Schéma | Principe | Avantage | Limite |
|--------|----------|----------|--------|
| `assume_role` dans le provider | un rôle central assume un rôle par compte | simple, un seul pipeline | le rôle central est très puissant |
| Un pipeline par compte | OIDC distinct par compte/environnement | isolation forte | davantage de configuration |
| Organizations + delegated admin | services délégués | gouvernance | dépend du cloud |

```hcl
provider "aws" {
  alias  = "securite"
  region = "eu-west-3"
  assume_role {
    role_arn     = "arn:aws:iam::333333333333:role/terraform-securite"
    session_name = "terraform-${terraform.workspace}"
    external_id  = var.external_id           # protection « confused deputy »
  }
  default_tags { tags = { GereePar = "terraform", Compte = "securite" } }
}
```

### Multi-région : bonnes pratiques
- Régions en **variables** ou locals, avec une liste centralisée (pas de chaînes `"eu-west-3"` éparpillées).
- Attention aux services **globaux** (IAM, Route 53, CloudFront) : ne les dupliquez pas par région.
- Les ressources répliquées exigent souvent un **chiffrement par région** (une clé KMS par région).
- Prévoir le nommage : noms de ressources globalement uniques (buckets) → suffixe région/compte.
- Tester le PRA : une réplique jamais utilisée est une hypothèse, pas une garantie.

### `default_tags` et héritage de configuration
`default_tags` (AWS) pose automatiquement des tags sur toutes les ressources qui les supportent. Les tags propres à une ressource les fusionnent et les surchargent. Attention au bruit dans les plans lorsque les mêmes tags sont définis aux deux endroits. Le provider `google` propose `default_labels`, `azurerm` n'a pas d'équivalent natif (utiliser une `locals` + `merge`).

### Limites actuelles et solutions
| Limite | Contournement |
|--------|--------------|
| Pas de `for_each` sur `provider` | écrire les alias, générer le code (Terragrunt, `cdktf`), ou OpenTofu (≥ 1.9 : `for_each` sur providers) |
| Alias non dynamiques dans un module | passer `providers = {}` depuis le parent explicite |
| Un provider ne peut pas dépendre d'une ressource créée dans le même état | découper en couches |
| Beaucoup de providers = `init` lent | cache de plugins, miroir |

## Exercices
1. Lisez `solution/main.tf` et le module. `terraform init -backend=false && terraform validate`.
2. Retirez `configuration_aliases` du module : quelle erreur ?
3. Ajoutez une 3ᵉ région (`ap`) avec un 2ᵉ bucket répliqué.
4. Créez un module qui crée un certificat ACM dans `us-east-1` (obligatoire pour CloudFront) tout en étant appelé depuis une stack `eu-west-3`.
5. Défi : passez la config à un rôle `assume_role` dans un 2ᵉ compte.
6. `apply` réel (optionnel) : bucket + réplication ; vérifiez qu'un objet déposé apparaît dans la réplique ; **`destroy`** ensuite (videz les buckets versionnés).

## Corrigé
[`solution/`](solution/)
