# 04 — Le state

## Cours

Le **state** est la mémoire de Terraform : il associe chaque bloc `resource` à l'identifiant réel (ARN, ID…), stocke les attributs et les métadonnées de dépendance.

⚠️ Il peut contenir des **secrets en clair** → ne jamais le committer, chiffrer le backend (module 07).

### Commandes
```bash
terraform state list                      # lister les ressources suivies
terraform state show random_pet.nouveau   # détails d'une ressource
terraform state mv A B                    # renommer/déplacer (impératif)
terraform state rm A                      # oublier (ne détruit PAS la ressource réelle)
terraform state pull > backup.json        # exporter
terraform apply -refresh-only             # synchroniser le state avec la réalité (drift)
terraform apply -replace=ADDR             # forcer la recréation (remplace l'ancien `taint`)
terraform force-unlock ID                 # lever un verrou resté coincé (avec prudence)
```

### Refactoring déclaratif (préféré à `state mv`)
```hcl
moved   { from = random_pet.ancien  to = random_pet.nouveau }       # ≥ 1.1
import  { to = aws_s3_bucket.b  id = "mon-bucket" }                 # ≥ 1.5
removed { from = aws_s3_bucket.b  lifecycle { destroy = false } }   # ≥ 1.7
```
Avantage : relu en code review, rejouable sur **tous** les environnements.

### Verrouillage (lock)
Pendant `plan`/`apply`, le backend pose un verrou pour éviter deux écritures concurrentes. Un backend local verrouille via un fichier ; les backends distants via leur mécanisme propre.

## Exercices

1. Dans `exercice/`, créez `random_pet.ancien` + `local_file.trace`, `apply`.
2. Renommez la ressource en `nouveau` **sans** `moved` : que montre le plan ? (détruire + créer).
3. Annulez, ajoutez le bloc `moved` : le plan doit annoncer *« has moved »* et **0 to destroy**.
4. Faites `terraform state rm local_file.trace`. Lancez `plan` : le fichier existe toujours mais Terraform veut le recréer. Pourquoi ?
5. Simulez une dérive : supprimez `out/trace.txt`, lancez `terraform plan -refresh-only`, puis `apply -refresh-only`.
6. Sauvegardez le state (`state pull`), corrompez-le volontairement, restaurez avec `state push`.
7. Défi : décommentez le bloc `removed` pour sortir `local_file.trace` du state sans supprimer le fichier.

## Corrigé
[`solution/main.tf`](solution/main.tf) — le script [`scripts/validate-all.sh`](../../scripts/validate-all.sh) rejoue le scénario du `moved`.
