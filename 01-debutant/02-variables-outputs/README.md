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
