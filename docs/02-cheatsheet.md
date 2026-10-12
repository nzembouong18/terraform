# Aide-mémoire Terraform

## CLI
```bash
terraform init [-upgrade] [-backend=false] [-backend-config=f] [-migrate-state] [-reconfigure]
terraform fmt [-recursive] [-check]
terraform validate
terraform plan [-out=f] [-var k=v] [-var-file=f] [-target=ADDR] [-refresh-only] [-replace=ADDR] [-destroy] [-detailed-exitcode] [-lock-timeout=5m]
terraform apply [f | -auto-approve] [-parallelism=N]
terraform destroy [-target=ADDR]
terraform show [f] [-json]                  terraform output [-json | -raw nom]
terraform console                           terraform graph | dot -Tsvg > g.svg
terraform providers [lock|mirror|schema -json]
terraform workspace list|new|select|show|delete
terraform state list|show|mv|rm|pull|push
terraform import ADDR ID                    terraform force-unlock LOCK_ID
terraform test [-filter=f] [-verbose]       terraform login|logout
```

## Blocs
```hcl
terraform { required_version = "~> 1.9"  required_providers { aws = { source = "hashicorp/aws" version = "~> 5.0" } }  backend "s3" {} }
provider "aws" { region = "eu-west-3"  alias = "x" }
variable "v" { type = string  default = "a"  description = ""  sensitive = false  nullable = true  validation {...} }
locals { x = 1 }
resource "aws_x" "n" { count/for_each  provider  depends_on  lifecycle {...}  dynamic "b" {...}  provisioner "local-exec" {...} }
data "aws_x" "n" {}
module "m" { source = "./m"  version = "~> 1"  for_each/count  providers = {...}  depends_on }
output "o" { value = ...  description = ""  sensitive = true }
moved {from to}   import {to id}   removed {from lifecycle{destroy=false}}   check "c" { assert {...} }
```

## Références
`var.x` · `local.x` · `module.m.out` · `resource_type.name.attr` · `data.type.name.attr` · `each.key/each.value` · `count.index` · `self` · `path.module|root|cwd` · `terraform.workspace`

## Types & expressions
`string number bool list(T) set(T) map(T) object({a=T}) tuple([T,T]) any` · `optional(T, def)`
`cond ? a : b` · `[for x in l : f(x) if c]` · `{for k,v in m : k => v}` · `l[*].attr` · `<<-EOT ... EOT`

## Adresses d'instances
`aws_x.n` · `aws_x.n[0]` · `aws_x.n["k"]` · `module.m.aws_x.n` · `module.m["k"].aws_x.n[1]`

## Priorité des variables (faible → forte)
default < `TF_VAR_*` < `terraform.tfvars(.json)` < `*.auto.tfvars` < `-var-file` / `-var` (ordre CLI)

## Symboles du plan
`+` create · `-` destroy · `~` update in-place · `-/+` replace · `+/-` create-before-destroy · `<=` read (data) · `(known after apply)` valeur inconnue

## Versions marquantes
| Version | Nouveauté |
|---------|-----------|
| 0.12 | HCL2, `for`, `dynamic` |
| 0.13 | `count/for_each` sur modules |
| 1.1 | `moved` |
| 1.2 | `precondition/postcondition` |
| 1.3 | `optional()` dans objets |
| 1.4 | `terraform_data` |
| 1.5 | `import` déclaratif, `check`, `-generate-config-out` |
| 1.6 | `terraform test` |
| 1.7 | `removed`, `mock_provider`, `import` avec `for_each` |
| 1.8 | fonctions fournies par les providers |
| 1.9 | références à `var` dans les `validation` d'autres variables |
| 1.10 | valeurs éphémères, S3 `use_lockfile` |
| 1.11 | attributs write-only |
