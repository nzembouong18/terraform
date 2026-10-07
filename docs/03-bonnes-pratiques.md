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
