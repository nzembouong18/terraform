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

## Comprendre en profondeur

### Les familles d'erreurs, et à quel moment elles surviennent
| Phase | Commande | Erreurs typiques | Cause fréquente |
|-------|----------|------------------|-----------------|
| Analyse syntaxique | `validate`/`plan` | *Argument or block definition required*, *Unclosed configuration block* | accolade manquante, faute de frappe |
| Validation statique | `validate` | *Reference to undeclared resource*, *Unsupported argument* | mauvais nom/attribut |
| Initialisation | `init` | *Failed to query available provider packages*, *Inconsistent lock file* | contraintes de version, réseau, miroir |
| Évaluation | `plan` | *Invalid for_each argument*, *Invalid index*, *Cycle*, *Inconsistent conditional result types* | valeurs inconnues, types, graphe |
| Validation métier | `plan` | `validation`/`precondition` en échec | entrées invalides |
| Application | `apply` | 403/404/409, quotas, *already exists* | droits, ordre, conflit de nom |
| Cohérence | `apply` | *Provider produced inconsistent result* | bogue de provider |

Savoir **où** l'erreur est détectée indique **par où** chercher : syntaxe → relire le fichier ; plan → regarder les valeurs ; apply → regarder l'API cible et les droits.

### Lire un message d'erreur Terraform
```
│ Error: Invalid for_each argument
│
│   on main.tf line 12, in resource "local_file" "f":
│   12:   for_each = toset([random_pet.p.id])
│     ├────────────────
│     │ random_pet.p.id is a string, known only after apply
│
│ The "for_each" set includes values derived from resource attributes that cannot be determined until apply...
```
1. **Titre** : la catégorie du problème.
2. **Localisation** : fichier, ligne, bloc.
3. **Contexte** (`├───`) : la valeur évaluée et son état (connue ? inconnue ? sensible ?).
4. **Explication** : souvent la solution est suggérée (« use the -target argument to first apply only the resources that the for_each depends on »).

### Techniques d'isolation
- **Réduire** : copier la config dans un dossier vide, supprimer ce qui n'est pas lié à l'erreur, jusqu'à obtenir le plus petit exemple qui échoue.
- **`terraform console`** : évaluer les sous-expressions une par une (`var.x`, `local.y`, `random_pet.p.id` si le state existe).
- **`terraform plan -target=ADDR`** : planifier un sous-ensemble (diagnostic uniquement).
- **`terraform show` / `state show`** : l'état réel connu de Terraform.
- **`TF_LOG=TRACE`** + `TF_LOG_PATH` : appels du provider ; chercher `Request`, `Response`, codes HTTP.
- **Bissection Git** : retrouver le commit qui a introduit l'erreur (`git bisect`) si elle est récente.
- **Comparer deux plans** : `terraform show -json` sur les deux versions et `jq`/`diff`.

### Les erreurs d'`apply` côté cloud : check-list
1. **403 / AccessDenied** : l'identité de Terraform a-t-elle la permission exacte (lire le nom de l'action refusée) ?
2. **404 / NotFound** : ressource supprimée à la main ? dépendance non encore propagée (consistance éventuelle) ?
3. **409 / AlreadyExists** : nom non unique ? ressource existante à `import` ?
4. **429 / Throttling** : réduire `-parallelism`, activer les retries du provider.
5. **Quota** : demander une augmentation ou changer de région/SKU.
6. **Dépendance de suppression** : *DependencyViolation* → un objet dépendant (ENI, règle) bloque la destruction.
7. **Apply interrompu** : l'état peut être partiel → relancer `plan` ; si une ressource existe mais n'est pas dans le state, l'`import`.

### Après un `apply` raté : que se passe-t-il ?
Terraform **n'annule pas** ce qui a déjà été créé. Il enregistre dans le state les ressources réussies, marque (« tainted ») celles qui ont échoué en cours de création, puis s'arrête. Le `plan` suivant reprend où l'on en était : les ressources *tainted* seront recréées, les autres inchangées. Si la machine plante avant l'écriture du state, un fichier `errored.tfstate` est écrit localement : récupérez-le avec `terraform state push errored.tfstate`.

### Cas pratiques : questions à se poser
- *Le plan veut tout recréer.* Changement de nom (→ `moved`), changement de backend ou de state, provider différent, argument « forces replacement », ou state perdu.
- *Le plan n'est jamais vide.* Valeurs non déterministes (`timestamp()`), attribut normalisé différemment par l'API (ordre d'une liste), dérive externe permanente → `ignore_changes` ciblé.
- *« Known after apply » partout.* Un `depends_on` sur un module, ou une data source qui dépend d'une ressource non créée.
- *`init` échoue en CI mais pas en local.* Réseau/proxy, version de Terraform, plateformes absentes du lock file, cache corrompu (`rm -rf .terraform`).
- *Un `destroy` échoue.* `prevent_destroy`, dépendance cachée, objet non vide (bucket versionné), ressource déjà supprimée.

### Construire de bons réflexes de prévention
| Pratique | Évite |
|----------|-------|
| `terraform fmt` + `validate` en pre-commit | erreurs de syntaxe, diff bruyants |
| `validation` sur toutes les variables | erreurs d'API cryptiques |
| `terraform test` | régressions de logique |
| Revue du **plan** (pas seulement du code) | surprises de remplacement |
| Versions épinglées + lock file | « ça marchait hier » |
| Backend distant + verrou | corruptions et doublons |
| Petits changements fréquents | plans ingérables, causes difficiles à isoler |

## Grille de réussite
Pour chaque scénario vous devez pouvoir dire : **la cause**, **pourquoi Terraform l'a détectée à ce moment** (validate / plan / apply), et **comment l'éviter** (validation, test, lint, revue).

## Corrigés
[`solutions/`](solutions/) — les 6 corrections sont vérifiées par `scripts/validate-all.sh` (les cassés échouent, les corrigés passent).
