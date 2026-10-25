# 05 — Boucles et conditions

## `count` vs `for_each`

| | `count` | `for_each` |
|--|---------|-----------|
| Entrée | un nombre | une `map` ou un `set(string)` |
| Adresse | `res.nom[0]`, `[1]`… | `res.nom["clé"]` |
| Retirer un élément du milieu | **décale** les index → destructions/recréations | seul l'élément retiré disparaît ✅ |
| Usage idéal | 0 ou 1 (condition) | collections d'objets distincts |

```hcl
resource "x" "cond" {
  count = var.actif ? 1 : 0          # pattern « if »
}

resource "x" "multi" {
  for_each = var.equipes             # each.key / each.value
}

resource "x" "set" {
  for_each = toset(var.liste)
}
```
> Les clés de `for_each` doivent être **connues au plan** (pas de valeur « known after apply » comme clé).

## Expressions `for`
```text
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

## Comprendre en profondeur

### Pourquoi `count` est fragile : l'effet de décalage
Avec `count`, l'identité d'une instance est son **index**. Soit `noms = ["a", "b", "c"]` : `res[0]=a`, `res[1]=b`, `res[2]=c`. Si l'on retire `"a"`, la liste devient `["b", "c"]` : `res[0]` doit maintenant être `b`, `res[1]` devient `c`, et `res[2]` disparaît. Terraform voit donc **deux modifications et une destruction** au lieu d'une seule suppression. Avec `for_each`, l'identité est la **clé** (`res["a"]`) : retirer `a` ne détruit que `a`.

> Règle pratique : `count` pour « 0 ou 1 » (activer/désactiver), `for_each` pour tout le reste.

### Types acceptés par `for_each`
- une **map** (`each.key` = clé, `each.value` = valeur) ;
- un **set de chaînes** (`each.key == each.value`) — convertissez une liste avec `toset()` ;
- le résultat d'une expression `for` produisant une map.

Une liste d'objets n'est **pas** acceptée directement : transformez-la en map avec une clé stable :
```hcl
locals {
  serveurs = { for s in var.liste_serveurs : s.nom => s }   # clé = nom (unique et stable)
}
resource "aws_instance" "srv" {
  for_each      = local.serveurs
  instance_type = each.value.taille
  tags          = { Name = each.key }
}
```
Les clés doivent être **connues au moment du plan** et **uniques**. Une clé dérivée d'un ID généré (`aws_x.y.id`) provoque l'erreur *« for_each value depends on resource attributes that cannot be determined until apply »*.

### Référencer les instances créées
| Construction | Référence | Forme obtenue |
|--------------|-----------|---------------|
| `count = 3` | `res.nom[1].id` | liste |
| `count = var.actif ? 1 : 0` | `one(res.nom[*].id)` | valeur ou `null` (propre) |
| `for_each` | `res.nom["web"].id` | map |
| toutes les instances | `values(res.nom)[*].id` ou `[for r in res.nom : r.id]` | liste |

Pour la condition « 0 ou 1 », préférez `one()` à `res.nom[0]` : ce dernier lève une erreur si `count = 0`.

### Enchaîner les boucles : aplatir des structures imbriquées
Cas courant : plusieurs équipes, chacune avec plusieurs membres → une ressource par couple (équipe, membre).
```hcl
locals {
  membres = flatten([
    for equipe, d in var.equipes : [
      for m in d.membres : { cle = "${equipe}-${m}", equipe = equipe, nom = m }
    ]
  ])
}
resource "x" "membre" {
  for_each = { for m in local.membres : m.cle => m }
  # each.value.equipe, each.value.nom
}
```
Le schéma « `flatten` + liste d'objets + map indexée par une clé composite » est **le** motif à connaître pour `for_each` sur des données imbriquées. Pour un produit cartésien, voir aussi `setproduct()`.

### Conditions : tous les outils
| Besoin | Outil |
|--------|-------|
| Choisir une valeur | ternaire `cond ? a : b` |
| Créer ou non une ressource | `count = cond ? 1 : 0` ou `for_each = cond ? {x = 1} : {}` |
| Argument facultatif | `argument = cond ? valeur : null` |
| Bloc imbriqué facultatif | `dynamic "bloc" { for_each = cond ? [1] : [] … }` |
| Valeur de repli | `try()`, `coalesce()`, `lookup(map, clé, défaut)` |
| Rejeter une entrée invalide | `validation`, `precondition` |

Piège : les **deux branches** d'un ternaire doivent avoir un type compatible (`cond ? "a" : 1` échoue). Convertissez explicitement (`tostring`).

### `dynamic` : quand l'utiliser
```hcl
dynamic "ingress" {
  for_each = { for r in var.regles : r.nom => r }
  iterator = regle                    # renomme la variable d'itération (défaut : nom du bloc)
  content {
    description = regle.key
    from_port   = regle.value.port
    to_port     = regle.value.port
    protocol    = "tcp"
    cidr_blocks = regle.value.cidr
  }
}
```
Réservez `dynamic` aux blocs dont **le nombre varie réellement**. Pour 2 règles fixes, écrivez 2 blocs : c'est plus lisible, plus facile à relire en revue et à rechercher (`grep`).

### Récapitulatif : choix de l'outil
```
Je veux répéter…
├─ 0 ou 1 fois, selon une condition ........... count = cond ? 1 : 0
├─ N fois identique, N est un nombre fixe ..... count = N        (rare)
├─ une fois par élément d'une collection ...... for_each = map / toset(...)
├─ un bloc imbriqué dans une ressource ........ dynamic "bloc"
└─ transformer / filtrer des données .......... expression for (pas de ressource)
```

## Exercices
1. Avec `count = 3`, appliquez ; puis passez à `count = 2` : quel fichier est supprimé ?
2. Convertissez une liste de 3 noms en `for_each` ; **retirez le 1er nom**. Comparez avec la version `count` (utilisez `plan`) : quel est l'impact ?
3. Filtrez les équipes `actif = false` avec une expression `for ... if`.
4. Créez un output qui compte les membres par équipe.
5. Passez `-var creer_rapport=false` : que devient `local_file.rapport[0]` ?
6. Défi : générez des règles de pare-feu `ingress` avec `dynamic` pour `aws_security_group` (voir [projet final](../../05-projet-final/modules/application/main.tf)).

## Corrigé
[`solution/main.tf`](solution/main.tf)
