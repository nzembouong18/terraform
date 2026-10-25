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
moved {       # ≥ 1.1
  from = random_pet.ancien
  to = random_pet.nouveau
}
import {                 # ≥ 1.5
  to = aws_s3_bucket.b
  id = "mon-bucket"
}
removed {   # ≥ 1.7
  from = aws_s3_bucket.b

  lifecycle {
    destroy = false
  }
}
```
Avantage : relu en code review, rejouable sur **tous** les environnements.

### Verrouillage (lock)
Pendant `plan`/`apply`, le backend pose un verrou pour éviter deux écritures concurrentes. Un backend local verrouille via un verrou système sur le fichier (libéré automatiquement si le processus meurt) ; les backends distants via leur mécanisme propre.

### À quoi sert (vraiment) le state ?
1. **Mapping** : lier `aws_s3_bucket.logs` (nom dans le code) à l'identifiant réel (`acme-logs-prod`). Sans cela, Terraform ne saurait pas quelle ressource correspond à quel bloc.
2. **Métadonnées** : dépendances, ordre de destruction, version du schéma du provider.
3. **Performance** : éviter d'interroger l'API pour chaque ressource à chaque plan sur de très grandes infrastructures (`-refresh=false`).
4. **Synchronisation d'équipe** : un backend distant partage cet état et le verrouille.

### Anatomie du fichier `terraform.tfstate`
```json
{
  "version": 4,
  "terraform_version": "1.9.8",
  "serial": 12,                    // incrémenté à chaque écriture : détecte les conflits
  "lineage": "6f1b…",              // identifiant unique de cet état (évite de mélanger deux états)
  "outputs": { "nom": { "value": "chat-bleu", "type": "string" } },
  "resources": [{
    "mode": "managed", "type": "random_pet", "name": "nouveau",
    "provider": "provider[\"registry.terraform.io/hashicorp/random\"]",
    "instances": [{ "attributes": { "id": "chat-bleu", "length": 2 } }]
  }]
}
```
**Ne l'éditez jamais à la main** : passez par `terraform state …` ou par les blocs `moved`/`import`/`removed`. Le format est interne et peut évoluer.

### Cycle de vie : refresh, plan, apply, destroy
```
          ┌───────────── refresh ─────────────┐
code ──► plan ◄── state ◄── (API : lire l'existant) 
           │
           ▼
         apply ──► appels d'API ──► nouveau state (serial + 1)
```
- Depuis Terraform 0.15.4, `plan` et `apply` **rafraîchissent le state en mémoire** avant de comparer ; le mode `-refresh-only` n'applique **que** la mise à jour du state (sans toucher à l'infra) et remplace l'ancienne commande `terraform refresh`.
- Si une ressource a été supprimée manuellement, le refresh la retire du state et le plan proposera de la **recréer**.
- Si un attribut a été modifié manuellement, le plan proposera de le **remettre** à la valeur du code (c'est le principe de la détection de dérive).

### Gérer la dérive (drift)
| Situation | Stratégie |
|-----------|-----------|
| La modification manuelle était une **erreur** | `terraform apply` : le code l'emporte |
| La modification manuelle est **légitime** (ex. autoscaling) | mettre à jour le code, ou `ignore_changes` sur l'attribut concerné |
| On veut simplement **enregistrer** la réalité | `terraform apply -refresh-only` |
| On veut **détecter** sans agir | `terraform plan -detailed-exitcode` planifié en CI (code 2 = dérive) |

### Backends : où vit le state
- **local** (`terraform.tfstate` dans le dossier) : bien pour apprendre ; **dangereux** en équipe (pas de partage, pas de verrou, perte du poste = perte de l'infra connue).
- **distant** (S3, GCS, Azure Blob, HCP Terraform…) : partagé, verrouillé, versionné, chiffré (module 07).
- Le state est découpé en **états multiples** (par application, par environnement) pour limiter le *rayon d'explosion* et accélérer les plans.

### Que contient le state, et pourquoi c'est sensible
Tous les attributs de toutes les ressources, **y compris** les mots de passe générés, les clés privées TLS, les chaînes de connexion. Conséquences :
- accès en lecture au state ≈ accès aux secrets ;
- interdire l'écriture directe hors CI (un attaquant qui modifie le state peut faire détruire ou rediriger des ressources) ;
- utiliser les attributs *write-only* / valeurs éphémères quand le provider les propose (module 13).

### Récupération après incident
| Incident | Réponse |
|----------|---------|
| Verrou resté coincé après un job CI tué (backend **distant** ; le backend local utilise un verrou système libéré dès la mort du processus) | `terraform force-unlock <ID>` **après** vérification qu'aucun apply n'est en cours |
| State corrompu / écrasé | restaurer la version précédente du backend (versioning S3, `state push`) |
| State perdu mais infra existante | recréer la config et **réimporter** chaque ressource (`import`) |
| Ressource supprimée du state par erreur | `terraform import` pour la reprendre |
| Deux personnes ont appliqué en parallèle sans verrou | comparer `serial`/`lineage`, restaurer, rejouer un `plan` |

### Commandes d'inspection utiles
```bash
terraform state list 'aws_instance.*'     # filtrer par motif
terraform state show 'aws_instance.web["a"]'
terraform show -json | jq '.values.root_module.resources[] | {address, type}'
terraform providers                       # providers et leurs sources requises
```

### Pièges
- `state rm` **n'a aucun effet sur le monde réel** : la ressource continue d'exister (et coûter), mais Terraform l'oublie ; au prochain `apply` il voudra la créer à nouveau.
- Les blocs `moved` ne fonctionnent qu'**à l'intérieur d'une même stack/state** : pour passer d'un state à l'autre, utilisez `import` + `removed`.
- Mélanger des **workspaces** et des **backends** différents sans comprendre où se trouve chaque state mène à des doublons.

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
