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
```hcl
templatefile("${path.module}/templates/nginx.conf.tftpl", { serveur = "app", ports = [80, 443] })
```
Directives : `${ }` interpolation, `%{ for x in l ~} ... %{ endfor ~}`, `%{ if cond ~} ... %{ endif ~}` (le `~` retire les sauts de ligne).

## `cidrsubnet(prefix, newbits, netnum)`
`cidrsubnet("10.20.0.0/16", 8, 2)` → `10.20.2.0/24` (on ajoute 8 bits au masque, 2 = numéro du sous-réseau).

## Exercices
1. `terraform console` : évaluez `cidrsubnet("10.0.0.0/16", 4, 3)`, `formatdate("YYYY-MM-DD", timestamp())`, `regex("[0-9]+", "build-42")`.
2. Dans `solution/`, lisez `out/nginx.conf` généré. Ajoutez un 3e amont et un bloc `%{ if }`.
3. Écrivez un `local` qui découpe `10.0.0.0/16` en 4 sous-réseaux /20 avec `cidrsubnets`.
4. Utilisez `try()` pour lire une clé optionnelle d'un objet sans erreur.
5. Défi : produire un fichier YAML à partir d'une map imbriquée avec `yamlencode`.

## Corrigé
[`solution/`](solution/)
