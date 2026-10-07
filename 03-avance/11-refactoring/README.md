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

## Exercices
1. Lisez `solution/main.tf`. Reproduisez le scénario de test de [`scripts/validate-all.sh`](../../scripts/validate-all.sh) : créez la version « avant » (`random_pet.a` + `local_file.rapport` à la racine), `apply`, puis passez à la version « après » : le plan annonce **2 déplacements, 0 destruction**.
2. Tentez la même chose **sans** les `moved` : qu'annonce le plan ?
3. **Import** : créez `random_id.test` dans un dossier A (`byte_length = 4`), notez `terraform output`/`state show` pour son id ; dans un dossier B vide, déclarez la ressource + un bloc `import`, puis `plan`.
4. Avec `-generate-config-out`, importez un fichier ou une ressource de votre choix et nettoyez la config générée.
5. Passez un `count = 3` en `for_each` avec des `moved` (de `[0]` vers `["a"]`) sans destruction.
6. Défi (cloud) : adoptez un bucket S3 créé à la main dans un module du [module 15](../../04-expert/15-module-qualite/README.md).

## Corrigé
[`solution/`](solution/)
