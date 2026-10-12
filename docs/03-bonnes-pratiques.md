# Bonnes pratiques Terraform

## Code
- **Structure standard** d'un module : `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`.
- **Nommage** : snake_case ; le nom d'une ressource ne répète pas son type (`aws_s3_bucket.logs`, pas `aws_s3_bucket.logs_bucket`) ; `this`/`main` si unique.
- **`terraform fmt`** et `validate` systématiques (pre-commit + CI).
- **Variables** : toujours `type` + `description` ; `validation` pour les formats ; pas de default pour un secret ; objets typés plutôt que `any`.
- **`for_each` > `count`** sauf pour le booléen 0/1.
- **Éviter** : `depends_on` en excès, `-target` en routine, provisioners (dernier recours), `null_resource` (préférer `terraform_data`), logique trop dynamique illisible.
- **Pas de valeurs magiques** : utiliser `locals` et des data sources (AMI, zones) plutôt que des IDs en dur.
- **Tags** : `default_tags` du provider + tags de gouvernance (`projet`, `proprietaire`, `environnement`, `cout`).

## Versions
- `required_version` et `required_providers` avec contraintes `~>`.
- **Committer** `.terraform.lock.hcl` ; générer les hash multi-plateformes : `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64`.
- Modules distants : épinglés (`version = "~> 5.0"` ou `?ref=v1.2.3`).
- Même version de Terraform pour tous (tfenv/`.terraform-version`, image CI).

## État
- Backend distant, chiffré, versionné, verrouillé. **Un état par couche et par environnement.**
- Jamais d'édition manuelle du state ; `moved`/`import`/`removed` en code.
- Sauvegarde avant toute opération de chirurgie (`terraform state pull > backup.json`).
- Pas de secrets dans les outputs ; considérer le state comme confidentiel.

## Processus
- Tout changement par **PR** avec plan relu ; apply automatisé depuis la CI.
- Petites PR, un sujet à la fois ; revue centrée sur le **plan** (`destroy`/`replace` = alerte).
- `prevent_destroy` sur les ressources critiques (bases, buckets d'état) + protections côté cloud (deletion protection).
- Tests (`terraform test`), lint (`tflint`), sécurité (`checkov`/`trivy`), policies (OPA).
- Documentation des décisions (ADR) et runbooks d'exploitation.

## Modules
- Un module = une responsabilité ; composition au niveau racine.
- Outputs complets, SemVer, `CHANGELOG`, exemples exécutables.
- Ne pas imbriquer au-delà de 2–3 niveaux ; ne pas wrapper un module sans valeur ajoutée.

## Anti-patterns courants
| Anti-pattern | Conséquence | Alternative |
|--------------|-------------|-------------|
| Un énorme état « tout-en-un » | plans lents, risque élevé | découpage par couche/env |
| `terraform apply` depuis un laptop en prod | non traçable, dérive | CI/CD + OIDC |
| `count` sur liste de noms | recréations lors d'une suppression | `for_each` |
| Secrets en `default` ou `.tfvars` commités | fuite | coffre / env / éphémère |
| Copier-coller d'un environnement à l'autre | divergences | modules + variables |
| `ignore_changes = all` | dérive invisible | cibler les attributs |
| Provider configuré dans un module | module non détruisible | provider passé par le racine |
| Corriger à la main dans la console | dérive | corriger le code, ré-appliquer |

## Pour aller plus loin

### Conventions de style (lisibilité)
- Ordre dans un bloc `resource` : meta-arguments (`count`/`for_each`, `provider`) d'abord, puis arguments, puis blocs imbriqués, puis `tags`, enfin `depends_on` et `lifecycle`.
- Une ligne vide entre les blocs ; `terraform fmt` fait le reste.
- Commentaires : expliquer le **pourquoi** (décision, contrainte), pas le **quoi**.
- Un fichier par thème quand un `main.tf` dépasse ~300 lignes (`network.tf`, `iam.tf`, `compute.tf`).
- Éviter les noms de ressource génériques (`this`) si un module en contient plusieurs du même type.

### Nommage des ressources cloud
Convention suggérée : `<organisation>-<projet>-<environnement>-<rôle>[-<région>]`, ex. `acme-shop-prod-logs-euw3`. Centralisez-la dans un `local` (`name_prefix`) : un changement de convention se fait à un seul endroit.

### Modèle de revue d'une PR d'infrastructure
1. Le **titre** et la description expliquent l'intention et le risque.
2. Le **plan** est joint (ou commenté automatiquement) ; la revue s'attache à `destroy`, `replace`, `~ in-place` sensibles (IAM, réseau).
3. Les **tests** et contrôles automatiques passent.
4. Le changement est **réversible** ? Plan de retour arrière décrit si non.
5. Le **coût** et la **sécurité** sont considérés (Infracost, politique).
6. Les changements de **modules** respectent SemVer.

### Cycle de vie d'un changement
```
Issue / besoin ─► branche ─► code + tests locaux (fmt, validate, test)
 ─► PR + plan automatique ─► revue ─► merge ─► apply (dev) ─► validation ─► promotion (recette, prod)
 ─► surveillance (dérive, coûts) ─► amélioration continue
```

### Travailler à plusieurs
- `CODEOWNERS` : revue obligatoire par les propriétaires des couches sensibles.
- Branches courtes, PR petites ; « merge train » ou file d'attente si de nombreux apply concurrents.
- Documentation vivante : README de stack (objectif, dépendances, commandes), ADR pour les choix structurants, runbooks pour l'exploitation.
- Accès : principe du moindre privilège dès le dépôt (branches protégées, rôles, secrets).

### Performance et confort
- Cache de providers (`TF_PLUGIN_CACHE_DIR`), `-parallelism` adapté à l'API, états de taille raisonnable.
- Pas de `data source` coûteuse (listes très longues) évaluée à chaque plan sans besoin.
- Éviter les modules imbriqués profonds qui multiplient les dépendances et rallongent `init`.

### Checklist de revue de module
- [ ] Interface minimale, types précis, `validation` utile
- [ ] Valeurs par défaut sûres (chiffrement, accès restreint)
- [ ] Aucun provider configuré dans le module
- [ ] Outputs documentés et stables
- [ ] Tests (`terraform test`) et exemple exécutable
- [ ] Compatible avec `count`/`for_each` appelant (pas de dépendance cachée)
- [ ] Changements compatibles ou version majeure + guide de migration

### Dette technique : signes d'alerte
Plans qui durent > 10 minutes, `-target` devenu habituel, états à plus de 1 000 ressources, dérives chroniques ignorées, mises à jour de providers repoussées pendant des mois, outputs jamais utilisés, modules copiés plutôt que versionnés. Inscrivez le désendettement dans le planning (une PR de « jardinage » par sprint).
