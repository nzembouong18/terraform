# 22 — Atelier de débogage

Six configurations **cassées volontairement**. Pour chacune : lancez `terraform init && terraform plan`, **lisez l'erreur**, formulez l'hypothèse, corrigez, vérifiez. Comparez ensuite avec `solutions/`.

Tout est hors-ligne (providers `local`/`random`).

## Méthode
1. Lire le message **en entier** (fichier, ligne, cause).
2. `terraform validate` (erreurs statiques) puis `terraform plan` (erreurs d'évaluation).
3. Isoler : commenter, réduire, `terraform console`.
4. Si besoin : `TF_LOG=DEBUG`, `terraform state show`, `terraform graph`.
5. Corriger **la cause** (pas le symptôme).

## Scénarios
| # | Dossier | Symptôme à observer | Notion |
|---|---------|---------------------|--------|
| 01 | [`exercices/01`](exercices/01) | `Invalid default value for variable` | typage (`list(number)`) |
| 02 | [`exercices/02`](exercices/02) | `Error: Cycle: local_file.a, local_file.b` | graphe de dépendances |
| 03 | [`exercices/03`](exercices/03) | `Invalid for_each argument ... known only after apply` | valeurs inconnues au plan |
| 04 | [`exercices/04`](exercices/04) | `Output refers to sensitive values` | propagation de `sensitive` |
| 05 | [`exercices/05`](exercices/05) | `Unsupported Terraform Core version` / provider introuvable | contraintes de version |
| 06 | [`exercices/06`](exercices/06) | `Inconsistent conditional result types` | types des conditionnelles |

Indices : 01 *quelle valeur n'est pas un nombre ?* · 02 *qui référence qui ?* · 03 *quand `random_pet.id` est-il connu ?* · 04 *que doit déclarer l'output ?* · 05 *que dit `terraform version` ?* · 06 *comparez le type des deux branches.*

## Scénarios « comportementaux » (à mener à la main, sans erreur affichée)
**A. Le renommage destructeur.** Créez `random_pet.a` + `local_file.f` (contenu = pet), `apply`. Renommez `a` → `b` : le plan annonce `1 to add, 1 to destroy`. Corrigez avec un bloc `moved` → `0 to destroy`.

**B. La dérive.** Appliquez un `local_file`, modifiez le fichier à la main, lancez `plan` : que voit-on ? Ajoutez `lifecycle { ignore_changes = [content] }` : que change-t-on ? Est-ce toujours souhaitable ?

**C. Le verrou resté coincé.** Lancez `terraform apply` sur un `terraform_data` avec un `provisioner "local-exec" { command = "sleep 120" }`, puis `kill -9` le processus Terraform. Relancez : que se passe-t-il (backend local) ? Quand utiliser `force-unlock` ?

**D. Le state perdu.** Supprimez `terraform.tfstate` après un `apply`, relancez `plan` : que veut faire Terraform ? Comment récupérer (`import`) ? Que mettre en place pour que cela n'arrive jamais (backend distant versionné) ?

**E. L'attribut qui « bouge » toujours.** Écrivez `content = timestamp()` dans un `local_file` : pourquoi le plan n'est-il jamais vide ? Corrigez avec `ignore_changes` ou une valeur stable.

## Grille de réussite
Pour chaque scénario vous devez pouvoir dire : **la cause**, **pourquoi Terraform l'a détectée à ce moment** (validate / plan / apply), et **comment l'éviter** (validation, test, lint, revue).

## Corrigés
[`solutions/`](solutions/) — les 6 corrections sont vérifiées par `scripts/validate-all.sh` (les cassés échouent, les corrigés passent).
