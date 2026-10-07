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

## Exercices
1. Lisez `solution/main.tf` et le module. `terraform init -backend=false && terraform validate`.
2. Retirez `configuration_aliases` du module : quelle erreur ?
3. Ajoutez une 3ᵉ région (`ap`) avec un 2ᵉ bucket répliqué.
4. Créez un module qui crée un certificat ACM dans `us-east-1` (obligatoire pour CloudFront) tout en étant appelé depuis une stack `eu-west-3`.
5. Défi : passez la config à un rôle `assume_role` dans un 2ᵉ compte.
6. `apply` réel (optionnel) : bucket + réplication ; vérifiez qu'un objet déposé apparaît dans la réplique ; **`destroy`** ensuite (videz les buckets versionnés).

## Corrigé
[`solution/`](solution/)
