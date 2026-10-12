# 02 — Variables, locals et outputs

## Cours

| Élément | Rôle | Analogie |
|---------|------|----------|
| `variable` | **entrée** du module/de la config | paramètre de fonction |
| `locals` | valeur calculée **interne** | variable locale |
| `output` | **sortie** exposée (CLI, autres modules, remote state) | valeur de retour |

### Types
`string`, `number`, `bool`, `list(T)`, `set(T)`, `map(T)`, `object({...})`, `tuple([...])`, `any`.
`optional(T, défaut)` dans un `object` (≥ 1.3) rend un champ facultatif.

### Validation
```hcl
variable "environnement" {
  type = string
  validation {
    condition     = contains(["dev", "recette", "prod"], var.environnement)
    error_message = "environnement doit valoir dev, recette ou prod."
  }
}
```

### Comment fournir une valeur (priorité croissante)
1. `default` de la variable
2. variables d'environnement `TF_VAR_nom`
3. `terraform.tfvars`, puis `terraform.tfvars.json`
4. `*.auto.tfvars` (ordre alphabétique)
5. `-var-file=fichier.tfvars` et `-var 'nom=valeur'` (dans l'ordre de la ligne de commande)

### `sensitive`
Masque la valeur dans le plan/les outputs. ⚠️ Elle reste **en clair dans le state**.

### Expressions utiles
- Interpolation : `"${var.projet}-${var.env}"`
- Conditionnelle : `var.prod ? 3 : 1`
- `for` : `[for s in var.liste : upper(s)]`, `{ for k, v in var.map : k => v }`
- Splat : `aws_instance.web[*].id`

### Anatomie complète d'une variable
```hcl
variable "port" {
  type        = number                 # contrat de type (fortement recommandé)
  description = "Port d'écoute HTTP."  # documentation (affichée par terraform-docs)
  default     = 8080                   # optionnel : sans default, la variable est OBLIGATOIRE
  nullable    = false                  # refuse null explicitement (défaut : true)
  sensitive   = false                  # masque la valeur dans l'affichage
  validation {
    condition     = var.port > 1023 && var.port < 65536
    error_message = "Le port doit être compris entre 1024 et 65535."
  }
}
```
- **Sans `type`**, la variable vaut `any` : Terraform déduit le type, ce qui masque des erreurs. Typez toujours.
- Terraform tente des **conversions implicites** sûres (`"5"` → `5`, `1` → `"1"`, `"true"` → `true`) mais refuse les autres.
- Plusieurs blocs `validation` sont permis ; depuis Terraform 1.9 une validation peut référencer **d'autres variables**.
- Une variable sans valeur, lancée en CI (`-input=false`), **fait échouer** le plan : c'est voulu.

### Types complexes : modéliser une configuration
```hcl
variable "services" {
  type = map(object({
    image    = string
    port     = number
    replicas = optional(number, 1)          # défaut 1
    tls      = optional(bool, true)
    env      = optional(map(string), {})
  }))
}
```
| Type | Caractéristique | Quand l'utiliser |
|------|-----------------|------------------|
| `list(T)` | ordonnée, doublons permis, accès par index | séquences (ports, sous-réseaux) |
| `set(T)` | **non ordonnée, sans doublons** | clés de `for_each` |
| `map(T)` | clés texte, valeurs **toutes du même type** | dictionnaire homogène |
| `object({...})` | attributs nommés, **types différents** | enregistrement structuré |
| `tuple([...])` | liste à types hétérogènes par position | rare |

`object` s'oppose à `map` : un `map(string)` est homogène, un `object` a un schéma figé. Pour un paramètre « structuré », préférez `object` avec `optional()` ; pour des « paires clé → valeur » libres (tags), préférez `map(string)`.

### Locals : nommer le calcul
```hcl
locals {
  prefixe = "${var.projet}-${var.environnement}"
  tags_communs = {
    Projet        = var.projet
    Environnement = var.environnement
    GereePar      = "terraform"
  }
  est_prod = var.environnement == "prod"
}
```
Un `local` n'est pas une entrée : on ne peut pas le surcharger de l'extérieur. Utilisez-le pour **éviter de répéter** une expression, donner un **nom métier** à un calcul, et centraliser les conventions de nommage et d'étiquetage. N'abusez pas : un local utilisé une seule fois, trivial, nuit à la lecture.

### Outputs : l'API de votre code
```hcl
output "urls" {
  description = "URL publique de chaque service."
  value       = { for nom, s in var.services : nom => "https://${nom}.${local.prefixe}.example.com" }
}
output "mot_de_passe" {
  value     = random_password.db.result
  sensitive = true                     # OBLIGATOIRE si la valeur dérive d'une valeur sensible
}
```
Un output sert à : afficher une information à l'utilisateur, **transmettre une valeur à un module parent** (`module.reseau.vpc_id`), ou exposer des données à une **autre stack** via `terraform_remote_state`. Commandes : `terraform output`, `terraform output -json` (pour scripts), `terraform output -raw nom` (valeur nue, sans guillemets).

### Précédence détaillée des sources de valeurs
De la moins prioritaire à la plus prioritaire :

1. valeur `default` du bloc `variable` ;
2. variables d'environnement `TF_VAR_<nom>` ;
3. `terraform.tfvars` puis `terraform.tfvars.json` ;
4. `*.auto.tfvars` et `*.auto.tfvars.json` (ordre lexical) ;
5. options `-var` et `-var-file` en ligne de commande (ordre d'apparition, la dernière gagne).

Bonne pratique : `default` pour ce qui est **raisonnable partout**, un fichier `envs/<env>.tfvars` pour ce qui diffère par environnement, `TF_VAR_` pour les **secrets** injectés par la CI. Si aucune source ne fournit une variable obligatoire, Terraform demande interactivement (sauf `-input=false`).

### Sensible : ce qui est (et n'est pas) protégé
| Surface | Protégée par `sensitive` ? |
|---------|:---:|
| Affichage du plan et de `apply` | ✅ (`(sensitive value)`) |
| `terraform output nom` | ✅ |
| `terraform output -raw nom` / `-json` | ❌ (affiché en clair, c'est voulu) |
| Fichier `terraform.tfstate` | ❌ **en clair** |
| Fichier de plan `tfplan` | ❌ en clair |
| Logs `TF_LOG=DEBUG` | ❌ peut fuiter |

La vraie protection passe par un **backend chiffré**, un accès restreint au state, et — pour les secrets — les valeurs **éphémères** (module 13).

### Expressions : tour d'horizon
```hcl
"${var.a}-${var.b}"                       # interpolation
var.prod ? 3 : 1                          # opérateur ternaire
var.liste[0]       var.map["cle"]        # accès index / clé
var.objet.attribut                        # accès attribut
[for s in var.liste : upper(s)]           # for → liste
{ for k, v in var.map : k => v * 2 }      # for → map
aws_instance.web[*].id                    # splat
try(var.objet.optionnel, "défaut")        # tolère l'absence
coalesce(var.a, var.b, "x")               # premier non-null / non-vide
```
Opérateurs : arithmétiques (`+ - * / %`), comparaison (`== != < <= > >=`), logiques (`&& || !`). **Pas de `if` statement** : tout passe par le ternaire, `count`, `for_each` ou des expressions `for ... if`.

### Pièges courants
- Valeur `null` : équivaut à « argument non fourni » (le provider applique son défaut) ; utile pour rendre un argument conditionnel : `kms_key_id = var.chiffre ? var.cle : null`.
- Une `list` n'est pas un `set` : `toset(["a","a"])` retire les doublons **et l'ordre**.
- Les variables `TF_VAR_` pour des types complexes doivent être écrites en JSON/HCL : `export TF_VAR_tags='{Projet="x"}'`.
- Une `validation` ne s'exécute pas sur une valeur *inconnue au plan* ; combinez-la avec `precondition` si besoin (module 03).

## Exercices

1. Créez une variable `projet` (string) **sans défaut**. Lancez `plan` : que se passe-t-il ? Fournissez-la de 4 façons différentes (`-var`, `TF_VAR_`, tfvars, prompt).
2. Ajoutez une validation de format sur `projet`. Testez avec `-var projet=A_B`.
3. Créez `locals` pour `prefixe = "${projet}-${environnement}"` et des `tags` fusionnés (`merge`).
4. Transformez une `list(object)` en `map` indexée par nom avec une expression `for`.
5. Marquez un mot de passe `sensitive`. Lancez `terraform output mot_de_passe`, puis `terraform output -raw mot_de_passe`, puis `grep` dans `terraform.tfstate`. **Conclusion ?**
6. Défi : produire un output `urls` (map nom → `https://nom.prefixe.example.com:port`) en choisissant `http`/`https` selon un champ `tls`.

## Corrigé
[`solution/`](solution/) : `variables.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars`.
`cd solution && terraform init && terraform apply -var 'projet=demo-app'`
