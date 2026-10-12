# Dépannage : erreurs fréquentes

| Symptôme | Cause probable | Résolution |
|----------|----------------|------------|
| `Error: Inconsistent dependency lock file` / provider introuvable | pas d'`init`, ou lock file différent | `terraform init -upgrade` |
| `Error acquiring the state lock` | apply concurrent ou crash | attendre ; vérifier qu'aucun run n'est actif ; `terraform force-unlock <ID>` en dernier recours |
| `Error: Invalid for_each argument ... known only after apply` | clés dépendant d'une ressource non créée | utiliser des clés connues (noms statiques), ou scinder en 2 applies / 2 états |
| `Cycle: a, b` | dépendances circulaires | casser le cycle (SG rules séparées, `depends_on` retiré, refactorer) |
| `Provider produced inconsistent result after apply` | bug de provider / ressource modifiée en parallèle | relancer ; mettre à jour le provider ; ouvrir une issue |
| Plan veut **détruire** après un renommage | nom changé sans `moved` | ajouter un bloc `moved` |
| Plan montre toujours un changement | attribut normalisé/calculé par le cloud (casse, ordre, JSON) | utiliser `jsonencode`, `lifecycle.ignore_changes` ciblé, mettre à jour le provider |
| `Error: Resource already exists` | ressource créée hors Terraform | `import` (ou renommer) |
| `AccessDenied` / `UnauthorizedOperation` | credentials/permissions | `aws sts get-caller-identity` ; vérifier le rôle assumé et la région |
| `Throttling` / 429 | trop d'appels parallèles | `-parallelism=5`, réessais du provider (`max_retries`) |
| `Error: Unsupported argument` après upgrade | changement de schéma du provider | lire le guide d'upgrade, adapter |
| Mise à jour du state interrompue | crash pendant l'apply | `terraform plan` ; `apply -refresh-only` ; `errored.tfstate` local à restaurer via `state push` |
| `No valid credential sources found` | profil/SSO expiré | `aws sso login`, `AWS_PROFILE` |
| `Module not installed` | nouveau module | `terraform init` |
| `Sensitive value in output` | output dérivé d'un sensible | `sensitive = true` sur l'output (ou `nonsensitive()` si sûr) |

## Méthode de diagnostic
1. **Lire le message en entier** (Terraform indique le fichier et la ligne).
2. `terraform validate` puis `terraform plan` (reproduisible ?).
3. `terraform console` pour tester une expression/valeur.
4. `TF_LOG=DEBUG terraform plan 2> debug.log` ; chercher la requête API en erreur.
5. `terraform state show <adresse>` : que sait Terraform ?
6. Comparer avec la console du cloud (réalité) → drift ou erreur de code ?
7. Isoler dans un petit module de reproduction (MRE).

## Cas supplémentaires, par thème

### Initialisation et versions
| Symptôme | Cause | Résolution |
|----------|-------|------------|
| `Unsupported Terraform Core version` | `required_version` incompatible avec le binaire | installer la bonne version (tfenv/mise) ou ajuster la contrainte |
| `provider registry.terraform.io/hashicorp/x ... does not have a package available for your current platform` | lock file sans le hash de votre plateforme | `terraform providers lock -platform=…` |
| `Failed to install provider` (réseau d'entreprise) | proxy/pare-feu | `HTTPS_PROXY`, miroir interne (`provider_installation`) |
| `Backend configuration changed` | bloc backend modifié | `terraform init -migrate-state` (copier) ou `-reconfigure` (ignorer) |
| `Error: Module not found` après changement de `source` | cache obsolète | `terraform init -upgrade` |

### Langage et évaluation
| Symptôme | Cause | Résolution |
|----------|-------|------------|
| `Invalid index` / `index out of range` | `res[0]` alors que `count = 0` | `one(res[*].attr)` ou `try()` |
| `Inconsistent conditional result types` | branches du ternaire de types différents | convertir (`tostring`, `tolist`) |
| `Invalid value for variable` | `validation` en échec | lire le message, corriger l'entrée |
| `Unsupported attribute` | attribut inexistant ou nom mal orthographié | lire la doc de la ressource, `terraform console` |
| `Variables not allowed` (dans un backend) | variables interdites dans `backend {}` | configuration partielle (`-backend-config`) |
| `Error: Reference to undeclared input variable` | variable utilisée mais non déclarée | déclarer le bloc `variable` |
| `Provider configuration not present` à la destruction | module supprimé alors que ses ressources sont dans le state | remettre le module/provider, détruire, puis retirer |

### State et refactoring
| Symptôme | Cause | Résolution |
|----------|-------|------------|
| Le plan veut tout recréer après un `terraform init -reconfigure` | state non migré, nouveau backend vide | restaurer la sauvegarde puis `init -migrate-state` |
| `Resource instance managed by newer provider version` | state écrit par un provider plus récent | utiliser la version de provider qui a écrit le state |
| `The state ... uses a newer Terraform version` | state écrit par un Terraform plus récent | utiliser une version ≥ ; ne pas rétrograder |
| `moved` ignoré | adresse source absente ou but déjà existant | vérifier `from`/`to`, état réel (`state list`) |
| `Cannot import non-existent remote object` | identifiant d'import erroné ou objet absent | vérifier le format d'ID dans la doc de la ressource |
| `Error: Instance cannot be destroyed` | `prevent_destroy = true` | assumer volontairement : retirer le garde-fou dans une PR dédiée |

### Cloud et API
| Symptôme | Cause | Résolution |
|----------|-------|------------|
| `BucketAlreadyExists` / nom déjà pris | nom globalement unique | suffixe aléatoire ou préfixe d'organisation |
| `DependencyViolation` (suppression) | objet encore référencé | détruire l'objet dépendant d'abord, ou corriger l'ordre |
| `InvalidParameterValue` après plusieurs `apply` réussis | propagation (consistance éventuelle) | relancer ; ajouter `time_sleep` ciblé si récurrent |
| `Timeout while waiting for state to become …` | opération longue ou bloquée | augmenter `timeouts {}`, inspecter la console du cloud |
| `409 Conflict` | opération concurrente sur la même ressource | sérialiser les applies, vérifier la CI |
| `RequestLimitExceeded` | quota d'API | `-parallelism`, `max_retries`, étaler les déploiements |

### Réseau et CI
| Symptôme | Cause | Résolution |
|----------|-------|------------|
| `terraform plan` bloque sur une invite | variable sans valeur | `-input=false` en CI et fournir toutes les variables |
| `Error: Failed to read variables file` | mauvais chemin de `-var-file` | chemin relatif au dossier d'exécution |
| Pipeline OK en local, KO en CI | version de Terraform/provider, plateforme du lock file, variables d'environnement | aligner les versions, relire le lock file |
| `Error: configuring Terraform AWS Provider: no valid credential sources` | OIDC mal configuré (permission `id-token: write` absente) | vérifier `permissions`, trust policy, `sub` |

## Arbre de décision : « mon plan n'est pas celui que j'attends »
```
Le plan montre des changements inattendus
├─ …des destructions/recréations ?
│    ├─ renommage ou déplacement de code ? ─────────► bloc moved
│    ├─ argument « forces replacement » modifié ? ──► volontaire ? sinon revenir en arrière
│    └─ backend/state changé ? ─────────────────────► restaurer le bon state
├─ …des modifications sur des ressources non touchées ?
│    ├─ modification manuelle dans le cloud ? ──────► dérive : appliquer ou ignore_changes ciblé
│    ├─ nouvelle version de provider ? ─────────────► lire le changelog, épingler
│    └─ valeur non déterministe (timestamp) ? ──────► stabiliser la valeur
└─ …aucune modification alors que j'en attends ?
     ├─ mauvais dossier / mauvais workspace ? ──────► terraform workspace show ; pwd
     ├─ -target ou -refresh=false oublié ? ─────────► retirer l'option
     └─ ressource hors state ? ─────────────────────► import
```

## Aide-mémoire des variables d'environnement utiles
| Variable | Rôle |
|----------|------|
| `TF_LOG`, `TF_LOG_PATH`, `TF_LOG_PROVIDER` | niveau et destination des logs |
| `TF_VAR_nom` | valeur d'une variable |
| `TF_IN_AUTOMATION=1` | adapte les messages à un contexte non interactif |
| `TF_INPUT=0` | équivalent de `-input=false` |
| `TF_CLI_ARGS_plan="-parallelism=5"` | arguments par défaut d'une sous-commande |
| `TF_DATA_DIR` | emplacement de `.terraform/` |
| `TF_PLUGIN_CACHE_DIR` | cache partagé des providers |
| `TF_WORKSPACE` | workspace à utiliser |
