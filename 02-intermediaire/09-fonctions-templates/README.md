# 09 — Fonctions et templates

Terraform fournit des fonctions intégrées (pas de fonctions utilisateur). Testez-les dans la console : `terraform console`.

| Catégorie | Fonctions à connaître |
|-----------|-----------------------|
| Chaînes | `format`, `join`, `split`, `replace`, `upper`, `lower`, `trimspace`, `substr`, `regex`, `strcontains` |
| Collections | `length`, `merge`, `concat`, `flatten`, `distinct`, `keys`, `values`, `lookup`, `element`, `slice`, `contains`, `zipmap`, `setunion` |
| Conversion | `tostring`, `tonumber`, `toset`, `tolist`, `jsonencode/decode`, `yamlencode/decode` |
| Réseau | `cidrsubnet`, `cidrhost`, `cidrnetmask`, `cidrsubnets` |
| Fichiers | `file`, `fileexists`, `templatefile`, `filebase64`, `abspath`, `path.module/root/cwd` |
| Robustesse | `try`, `can`, `coalesce`, `coalescelist`, `nonsensitive`, `one` |
| Hash/crypto | `md5`, `sha256`, `base64encode`, `uuid` (⚠️ change à chaque run) |

## `templatefile`
```text
templatefile("${path.module}/templates/nginx.conf.tftpl", { serveur = "app", ports = [80, 443] })
```
Directives : `${ }` interpolation, `%{ for x in l ~} ... %{ endfor ~}`, `%{ if cond ~} ... %{ endif ~}` (le `~` retire les sauts de ligne).

## `cidrsubnet(prefix, newbits, netnum)`
`cidrsubnet("10.20.0.0/16", 8, 2)` → `10.20.2.0/24` (on ajoute 8 bits au masque, 2 = numéro du sous-réseau).

## Comprendre en profondeur

### Explorer avec `terraform console`
La console évalue des expressions dans le contexte de votre configuration (variables, locals, state).
```text
> upper("terraform")
"TERRAFORM"
> [for i in range(3) : "srv-${i}"]
["srv-0", "srv-1", "srv-2"]
> merge({a = 1}, {b = 2, a = 9})        # la dernière clé gagne
{ "a" = 9, "b" = 2 }
> lookup({a = 1}, "z", 0)               # valeur par défaut
0
> element(["a","b","c"], 4)             # modulo : revient au début
"b"
> zipmap(["a","b"], [1,2])
{ "a" = 1, "b" = 2 }
```
On l'utilise en TDD léger : écrire l'expression dans la console, la valider, puis la coller dans le code.

### Familles de fonctions, avec exemples
**Chaînes**
```text
format("%s-%03d", "srv", 7)            # "srv-007"
join(",", ["a","b"])                   # "a,b"      split(",", "a,b") → ["a","b"]
replace("a.b.c", ".", "-")             # "a-b-c"
regex("^(\\w+)-(\\d+)$", "app-42")     # ["app", "42"]
trimprefix("v1.2.0", "v")              # "1.2.0"
```
**Collections**
```text
concat([1], [2, 3])                    # [1,2,3]          distinct([1,1,2]) → [1,2]
slice(["a","b","c"], 0, 2)             # ["a","b"]        sort / reverse / compact
setunion(["a"], ["b"])                 # ensemble         setsubtract / setintersection
transpose({a=["x","y"]})               # { x=["a"], y=["a"] }
```
**Nombres et dates**
```text
min(1,2)  max(3,4)  ceil(1.2)  floor(1.8)  abs(-3)  pow(2,8)
timestamp()                            # instant courant (change à chaque plan !)
timeadd("2025-01-01T00:00:00Z", "24h") # horodatage décalé
formatdate("DD/MM/YYYY", "2025-03-15T10:00:00Z")   # "15/03/2025"
```
**Robustesse (gestion des absences)**
```text
try(var.config.cache.ttl, 300)         # retombe sur 300 si le chemin n'existe pas
can(regex("^[a-z]+$", var.nom))        # booléen : l'expression s'évalue-t-elle sans erreur ?
coalesce("", null, "defaut")           # "defaut"  (ignore null ET "")
one([])                                # null       one(["x"]) → "x"
```
`can()` est idéal dans une `validation` : `condition = can(regex("^[a-z0-9-]{3,20}$", var.nom))`.

### Encodage / décodage de données
| Fonction | Usage |
|----------|-------|
| `jsonencode(obj)` / `jsondecode(str)` | politiques IAM, configurations JSON |
| `yamlencode(obj)` / `yamldecode(str)` | manifestes, fichiers de config |
| `base64encode` / `base64decode` | `user_data`, secrets Kubernetes |
| `file("chemin")` / `filebase64()` | lire un fichier **à l'init du plan** |
| `csvdecode(file(...))` | piloter `for_each` depuis un CSV |

Écrivez les politiques IAM avec `jsonencode({...})` plutôt qu'avec un heredoc JSON : Terraform valide la syntaxe, formate et permet d'insérer des références proprement.

### Chemins : `path.module`, `path.root`, `path.cwd`
- `path.module` : dossier du module **qui contient l'expression** → à utiliser pour charger ses propres fichiers (`file("${path.module}/script.sh")`).
- `path.root` : dossier du module racine.
- `path.cwd` : dossier de travail de la commande (≠ `root` si `-chdir`).
Oublier `path.module` fait échouer un module dès qu'il est appelé depuis un autre dossier.

### `templatefile` avancé
```text
# templates/inventaire.tftpl
%{ for nom, srv in serveurs ~}
[${nom}]
${srv.ip} ansible_user=${srv.user}
%{ endfor ~}
%{ if monitoring }
[monitoring]
${monitoring_host}
%{ endif ~}
```
```text
templatefile("${path.module}/templates/inventaire.tftpl", {
  serveurs        = { web = { ip = "10.0.1.10", user = "ubuntu" } }
  monitoring      = true
  monitoring_host = "10.0.9.5"
})
```
Règles : toutes les variables du modèle doivent être **fournies** dans la map ; `~` supprime l'espace/saut de ligne adjacent (contrôle du rendu) ; `$${...}` produit un `${...}` littéral. Un modèle ne peut pas appeler `templatefile` récursivement. Pour du JSON/YAML, préférez `jsonencode`/`yamlencode` (échappement correct garanti) plutôt qu'un template textuel.

### Calcul réseau avec `cidrsubnet`
Découper `10.0.0.0/16` en sous-réseaux /24 : `newbits = 8` (16 + 8 = 24), `netnum` = 0 à 255.
```hcl
locals {
  zones   = ["a", "b", "c"]
  publics = { for i, z in local.zones : z => cidrsubnet("10.0.0.0/16", 8, i) }        # 10.0.0.0/24, 10.0.1.0/24 …
  privés  = { for i, z in local.zones : z => cidrsubnet("10.0.0.0/16", 8, i + 10) }    # 10.0.10.0/24 …
}
```
`cidrsubnets("10.0.0.0/16", 4, 4, 8)` renvoie plusieurs blocs de tailles différentes sans chevauchement. `cidrhost("10.0.1.0/24", 5)` → `10.0.1.5`.

### Fonctions non déterministes à éviter
`timestamp()`, `uuid()`, `bcrypt()` donnent un résultat **différent à chaque plan**. Dans un argument de ressource, ils déclenchent une modification perpétuelle. Alternatives : `time_static`, `random_uuid` (stockés dans le state), ou `ignore_changes`.

### Limites du langage
- **Pas de fonctions utilisateur** ni de boucles `while` : tout est expression pure et déclarative.
- Pas d'effets de bord : les fonctions ne lisent que leurs entrées (et le disque pour `file`).
- Un calcul trop complexe est le signal qu'il faut simplifier la **structure de données** (changer le format de la variable d'entrée) plutôt que d'empiler des `flatten`/`zipmap`.
- Besoin d'une logique exotique : `external` data source (script), ou — mieux — un provider/une fonction de provider (`provider::nom::fonction`, ≥ 1.8).

## Exercices
1. `terraform console` : évaluez `cidrsubnet("10.0.0.0/16", 4, 3)`, `formatdate("YYYY-MM-DD", timestamp())`, `regex("[0-9]+", "build-42")`.
2. Dans `solution/`, lisez `out/nginx.conf` généré. Ajoutez un 3e amont et un bloc `%{ if }`.
3. Écrivez un `local` qui découpe `10.0.0.0/16` en 4 sous-réseaux /20 avec `cidrsubnets`.
4. Utilisez `try()` pour lire une clé optionnelle d'un objet sans erreur.
5. Défi : produire un fichier YAML à partir d'une map imbriquée avec `yamlencode`.

## Corrigé
[`solution/`](solution/)
