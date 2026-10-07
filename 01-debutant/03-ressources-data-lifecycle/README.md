# 03 — Ressources, data sources, dépendances et lifecycle

## Cours

### Graphe de dépendances
Terraform construit un **graphe orienté acyclique** : chaque référence (`random_password.db.result`) crée une **dépendance implicite**. Les ressources indépendantes sont créées **en parallèle** (10 par défaut, `-parallelism=N`).
`depends_on` ne sert que pour une dépendance **invisible** dans le code (ex. une règle IAM nécessaire avant une instance).

### Data sources
`data "type" "nom" {}` **lit** une ressource existante (AMI, VPC existant, fichier, zone DNS…). Référence : `data.type.nom.attribut`. Évaluée au plan quand c'est possible, sinon à l'apply.

### Meta-arguments `lifecycle`
| Option | Effet |
|--------|-------|
| `create_before_destroy` | crée le remplaçant avant de détruire l'ancien (zéro coupure) |
| `prevent_destroy` | erreur si le plan détruit la ressource (garde-fou, pas une sécurité absolue) |
| `ignore_changes = [attr]` | ignore les modifications externes sur ces attributs (ex. autoscaling) |
| `replace_triggered_by` | remplace la ressource quand une autre change |
| `precondition` / `postcondition` | contrats vérifiés avant/après la création |

### Autres meta-arguments : `count`, `for_each`, `provider`, `depends_on` (voir module 05).

## Exercices

1. Dans `solution/main.tf`, tracez le graphe : `terraform graph`. Quelles ressources sont parallélisables ?
2. Passez `prevent_destroy = true` sur `db_conf` puis `terraform destroy`. Lisez l'erreur. Remettez `false`.
3. Modifiez à la main `out/tolere.txt` : le plan voit-il un changement ? Pourquoi (`ignore_changes`) ?
4. Lancez `terraform apply -var taille_mot_de_passe=8` : quelle erreur ? D'où vient-elle (precondition) ?
5. Changez `random_password` (`-replace=random_password.db`) : quelle ressource est **aussi** remplacée grâce à `replace_triggered_by` ?
6. Défi : ajoutez une `postcondition` sur `data.local_file.readme_lu` qui exige que le contenu ne soit pas vide.

## Pièges
- `depends_on` abusif sur un **module** rend le plan opaque (« known after apply » partout).
- Les data sources qui dépendent d'une ressource non encore créée sont reportées à l'apply.

## Corrigé
[`solution/main.tf`](solution/main.tf)
