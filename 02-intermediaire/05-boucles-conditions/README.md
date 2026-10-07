# 05 — Boucles et conditions

## `count` vs `for_each`

| | `count` | `for_each` |
|--|---------|-----------|
| Entrée | un nombre | une `map` ou un `set(string)` |
| Adresse | `res.nom[0]`, `[1]`… | `res.nom["clé"]` |
| Retirer un élément du milieu | **décale** les index → destructions/recréations | seul l'élément retiré disparaît ✅ |
| Usage idéal | 0 ou 1 (condition) | collections d'objets distincts |

```hcl
resource "x" "cond"  { count = var.actif ? 1 : 0 }          # pattern « if »
resource "x" "multi" { for_each = var.equipes  # each.key / each.value }
resource "x" "set"   { for_each = toset(var.liste) }
```
> Les clés de `for_each` doivent être **connues au plan** (pas de valeur « known after apply » comme clé).

## Expressions `for`
```hcl
[for s in var.liste : upper(s)]                       # liste -> liste
{ for k, v in var.map : k => v.port }                 # map -> map
{ for s in var.liste : s.nom => s }                   # liste -> map indexée
[for e in var.equipes : e.membres if e.actif]         # filtre
flatten([for e in var.equipes : e.membres])           # aplatir
```
Splat : `local_file.numerote[*].filename` ≡ `[for f in local_file.numerote : f.filename]`.

## `dynamic` blocks
Génère des blocs imbriqués répétés :
```hcl
resource "aws_security_group" "web" {
  dynamic "ingress" {
    for_each = var.ports_ouverts          # [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
```
⚠️ N'en abusez pas : lisibilité en baisse. Réservez-les aux vrais cas variables.

## Exercices
1. Avec `count = 3`, appliquez ; puis passez à `count = 2` : quel fichier est supprimé ?
2. Convertissez une liste de 3 noms en `for_each` ; **retirez le 1er nom**. Comparez avec la version `count` (utilisez `plan`) : quel est l'impact ?
3. Filtrez les équipes `actif = false` avec une expression `for ... if`.
4. Créez un output qui compte les membres par équipe.
5. Passez `-var creer_rapport=false` : que devient `local_file.rapport[0]` ?
6. Défi : générez des règles de pare-feu `ingress` avec `dynamic` pour `aws_security_group` (voir [projet final](../../05-projet-final/modules/application/main.tf)).

## Corrigé
[`solution/main.tf`](solution/main.tf)
