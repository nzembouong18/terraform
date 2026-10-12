# 11 — Refactoring, import et chirurgie du state

## Règle d'or
> Modifier un **nom** dans le code = Terraform comprend « détruire l'ancien, créer le nouveau ». Pour éviter une destruction, il faut **expliquer le changement** à Terraform.

| Besoin | Outil | Version |
|--------|-------|---------|
| Renommer / déplacer une ressource, l'entrer dans un module, transformer `count`→`for_each` | bloc `moved` | ≥ 1.1 |
| Adopter une ressource **déjà existante** | bloc `import` (+ `-generate-config-out`) | ≥ 1.5 |
| Importer N ressources | `import` + `for_each` | ≥ 1.7 |
| Arrêter de gérer sans détruire | bloc `removed` | ≥ 1.7 |
| Cas exceptionnels, réparation | `terraform state mv/rm/pull/push` | toujours |

## `moved`
```hcl
moved { from = aws_instance.web          to = aws_instance.app }
moved { from = aws_instance.app          to = module.compute.aws_instance.app }
moved { from = aws_subnet.s[0]           to = aws_subnet.s["a"] }     # count -> for_each
```
Gardez les `moved` quelques versions pour que **tous** les environnements migrent, puis supprimez-les.

## `import` déclaratif
```hcl
import {
  to = aws_s3_bucket.legacy
  id = "mon-vieux-bucket"
}
```
```bash
terraform plan -generate-config-out=generated.tf   # écrit la config HCL pour vous (à relire/nettoyer !)
terraform apply
```
Procédure type d'adoption : 1) lister l'existant, 2) `import` + génération, 3) nettoyer le code généré (supprimer attributs calculés/valeurs par défaut), 4) **`plan` doit afficher 0 changement**, 5) retirer le bloc `import`.

## `removed`
```hcl
removed {
  from = aws_s3_bucket.legacy
  lifecycle { destroy = false }   # sort du state, la ressource réelle reste
}
```

## Comprendre en profondeur

### Pourquoi refactorer ?
Le code d'infrastructure vieillit : noms hérités, ressources plates devenues modules, `count` à convertir en `for_each`, états trop gros à scinder, ressources créées « à la main » à adopter. Chaque refactoring a le même risque : **Terraform lit un nouveau nom comme une nouvelle ressource**. Le but est de dire à Terraform « c'est le même objet, il a juste changé d'adresse ».

### La méthode sûre
1. **État propre** : `terraform plan` doit afficher *No changes* avant de commencer.
2. **Sauvegarde** : `terraform state pull > avant.tfstate`.
3. Modifier le code **et** ajouter les blocs `moved`/`import`/`removed`.
4. `terraform plan` : lire attentivement. Résultat attendu : *« has moved »* et **0 to add / 0 to destroy**.
5. `apply`, puis un second `plan` qui reste vide.
6. Garder les `moved` plusieurs versions (le temps que tous les environnements aient migré), puis les retirer.

> Un plan de refactoring qui détruit une ressource stateful (base, volume, bucket) doit **bloquer la PR**. Automatisez-le avec une politique (module 16) : « aucune action `delete` sur ces types ».

### Les cas de `moved`
```hcl
# 1. renommer
moved { from = aws_instance.web  to = aws_instance.app }
# 2. entrer dans un module
moved { from = aws_s3_bucket.logs  to = module.stockage.aws_s3_bucket.logs }
# 3. sortir d'un module
moved { from = module.ancien.aws_vpc.main  to = aws_vpc.main }
# 4. renommer un module
moved { from = module.web  to = module.frontend }
# 5. count → for_each
moved { from = aws_subnet.s[0]  to = aws_subnet.s["a"] }
moved { from = aws_subnet.s[1]  to = aws_subnet.s["b"] }
# 6. ressource unique → ressource avec count
moved { from = aws_instance.srv  to = aws_instance.srv[0] }
```
Un `moved` placé **dans un module publié** protège tous ses consommateurs lors d'un renommage interne : c'est la manière de livrer un renommage en version MINOR.

### `import` : adopter l'existant
Trois approches, de la plus moderne à la plus ancienne :

1. **Bloc `import` + génération** (≥ 1.5) :
   ```hcl
   import { to = aws_s3_bucket.legacy  id = "mon-vieux-bucket" }
   ```
   `terraform plan -generate-config-out=generated.tf` produit le HCL. Le code généré est **verbeux** (tous les attributs, y compris les valeurs par défaut) : nettoyez-le.
2. **Bloc `import` + code écrit à la main** : plus propre, vous contrôlez le résultat.
3. **Commande `terraform import ADDR ID`** (historique) : modifie le state immédiatement, sans revue ; à éviter en équipe.

Chaque ressource a un **format d'identifiant** propre, documenté en bas de la page de la ressource (`Import`). Exemples : `aws_s3_bucket` → nom, `aws_route53_record` → `ZONEID_nom_TYPE`, `aws_iam_role_policy_attachment` → `role/arn`. Certains objets ne sont **pas importables**.

Après un import, **lisez le plan** : tout écart entre votre code et la réalité apparaît comme une modification. Réduisez-le à zéro, soit en corrigeant le code, soit en acceptant volontairement la modification.

Import en masse (≥ 1.7) :
```hcl
import {
  for_each = var.buckets_existants          # set de noms
  to       = aws_s3_bucket.b[each.key]
  id       = each.value
}
```

### `removed` : cesser de gérer sans détruire
```hcl
removed {
  from = aws_s3_bucket.legacy
  lifecycle { destroy = false }        # sort du state, l'objet réel reste
}
```
Avec `destroy = true` (défaut), le bloc `removed` détruit la ressource ; l'avantage est de rendre cette suppression **explicite et revue en PR** plutôt qu'implicite par suppression du bloc `resource`.

### Découper un état en deux (migration entre stacks)
Un `moved` ne traverse pas les states. Procédure :
1. Dans la **nouvelle** stack : écrire les ressources + bloc `import` (ou `terraform import`).
2. `plan` : doit être vide.
3. Dans l'**ancienne** stack : bloc `removed { destroy = false }` puis `apply`.
4. Vérifier avec `plan` sur les deux stacks.
L'ordre importe : importer avant de retirer (jamais de moment où personne ne gère la ressource... ni où deux stacks la gèrent et se disputent).

### Commandes `state` (chirurgie, dernier recours)
```bash
terraform state mv aws_instance.a aws_instance.b           # équivaut à un moved, mais impératif
terraform state mv -state-out=autre.tfstate res res        # extraire vers un autre state
terraform state rm aws_instance.zombie                     # oublier une ressource
terraform state replace-provider registry.terraform.io/-/aws hashicorp/aws   # migration de provider
```
Toujours faire une copie du state avant. En équipe, préférez les blocs déclaratifs : ils sont relus, testés sur un plan et rejoués sur chaque environnement.

### Changer de version majeure de provider
1. Lire le guide d'upgrade (attributs supprimés, ressources scindées — ex. AWS S3 v4 a découpé `aws_s3_bucket` en `aws_s3_bucket_versioning`, `_server_side_encryption_configuration`…).
2. Brancher, `init -upgrade`, `plan` : repérer les changements « de schéma » sans impact réel.
3. Utiliser `import` pour les nouvelles ressources séparées, `lifecycle.ignore_changes` temporairement si nécessaire.

### Pièges
- `moved` vers une adresse qui existe déjà → erreur ; vérifiez qu'il n'y a pas déjà un objet à cette adresse.
- Un `moved` ne corrige pas les références obsolètes dans d'autres modules (`depends_on`, `module.x.sortie`).
- Importer une ressource **déjà gérée** par une autre stack provoque des conflits permanents (deux sources de vérité).
- Sur des ressources avec `prevent_destroy`, un refactoring mal préparé échoue tôt : c'est le comportement voulu.

## Exercices
1. Lisez `solution/main.tf`. Reproduisez le scénario de test de [`scripts/validate-all.sh`](../../scripts/validate-all.sh) : créez la version « avant » (`random_pet.a` + `local_file.rapport` à la racine), `apply`, puis passez à la version « après » : le plan annonce **2 déplacements, 0 destruction**.
2. Tentez la même chose **sans** les `moved` : qu'annonce le plan ?
3. **Import** : créez `random_id.test` dans un dossier A (`byte_length = 4`), notez `terraform output`/`state show` pour son id ; dans un dossier B vide, déclarez la ressource + un bloc `import`, puis `plan`.
4. Avec `-generate-config-out`, importez un fichier ou une ressource de votre choix et nettoyez la config générée.
5. Passez un `count = 3` en `for_each` avec des `moved` (de `[0]` vers `["a"]`) sans destruction.
6. Défi (cloud) : adoptez un bucket S3 créé à la main dans un module du [module 15](../../04-expert/15-module-qualite/README.md).

## Corrigé
[`solution/`](solution/)
