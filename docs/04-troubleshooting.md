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
