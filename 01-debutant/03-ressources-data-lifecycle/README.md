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

### Anatomie d'une ressource
```hcl
resource "aws_s3_bucket" "logs" {        # type = <provider>_<objet> ; nom local = logs
  bucket = "acme-logs-${var.env}"        # arguments  (ce que VOUS fournissez)
  tags   = local.tags
}
# attributs (ce que le provider calcule) : aws_s3_bucket.logs.arn, .id, .bucket_domain_name
```
- **Arguments** : entrées, écrites dans le code. **Attributs** : tout ce qui est lisible après création, y compris les arguments, plus les valeurs calculées (`id`, `arn`). La documentation de chaque ressource sépare *Argument Reference* et *Attribute Reference*.
- L'adresse complète d'une ressource (`aws_s3_bucket.logs`, `module.reseau.aws_vpc.main`, `aws_instance.web["a"]`) est sa **clé dans le state** : la changer, c'est changer d'identité (module 11).
- Les arguments se classent en trois familles : **modifiables en place**, **« forces replacement »** (la ressource est recréée) et **immuables après création**. La doc du provider et le plan l'indiquent ; toujours lire le plan avant d'appliquer.

### Dépendances implicites, explicites, et graphe
```hcl
resource "aws_vpc" "main"    { cidr_block = "10.0.0.0/16" }
resource "aws_subnet" "a" {
  vpc_id     = aws_vpc.main.id      # dépendance IMPLICITE : le subnet attend le VPC
  cidr_block = "10.0.1.0/24"
}
resource "aws_instance" "app" {
  subnet_id  = aws_subnet.a.id
  depends_on = [aws_iam_role_policy.app]   # dépendance EXPLICITE : lien invisible dans le code
}
```
Règle : **toujours préférer la référence** à `depends_on`. Une référence exprime la dépendance *et* transmet une donnée. Ordre de création : du parent vers l'enfant ; ordre de destruction : **inverse**. `terraform graph | dot -Tsvg > graphe.svg` visualise le résultat (nécessite Graphviz). Pour limiter l'impact :

```bash
terraform plan  -target=aws_instance.app     # ⚠️ exceptionnel (réparation) — cible une ressource + dépendances
terraform apply -parallelism=5                # moins de concurrence si l'API limite le débit (rate limit)
```
`-target` laisse un state partiel par rapport au code : ne l'utilisez pas en routine.

### Data sources : lire sans posséder
```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]            # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
resource "aws_instance" "web" { ami = data.aws_ami.ubuntu.id }
```
Une data source **ne crée ni ne détruit** rien : elle interroge l'API à chaque plan. Cas d'usage : récupérer un VPC existant, une zone DNS, l'identité courante (`aws_caller_identity`), un secret, un fichier. Elle échoue si l'objet est introuvable (utile : détecte tôt une erreur). Attention : une data source qui renvoie une valeur différente à chaque plan (ex. `most_recent = true`) peut provoquer des remplacements surprises ; épinglez les filtres ou les versions.

### Ressource ou data source ?
| Question | Réponse |
|----------|---------|
| Terraform doit-il créer, modifier, détruire l'objet ? | `resource` |
| L'objet existe déjà et appartient à une autre équipe/stack ? | `data` |
| L'objet doit entrer dans ma gestion progressivement ? | `import` (module 11) |

### Ressources « pures Terraform » (sans API externe)
Les providers `random`, `local`, `tls`, `time`, `null` créent des valeurs **dans le state** :

| Ressource | Usage | Point d'attention |
|-----------|-------|-------------------|
| `random_pet`, `random_id`, `random_password` | noms, suffixes, mots de passe | valeur **stable** une fois créée ; `keepers` la recrée quand une valeur change |
| `time_sleep`, `time_static` | attendre, figer une date | évite `timestamp()` qui change à chaque plan |
| `tls_private_key` | clé générée | **la clé privée est dans le state** |
| `terraform_data` | ressource « vide » pour déclencher/porter des triggers | remplace `null_resource` (≥ 1.4) |

### `lifecycle` en détail
```hcl
resource "aws_instance" "web" {
  # ...
  lifecycle {
    create_before_destroy = true                 # remplacement sans trou
    prevent_destroy       = true                 # refuse tout plan qui détruit
    ignore_changes        = [tags["Owner"], user_data]
    replace_triggered_by  = [aws_launch_template.web.latest_version]

    precondition {                               # vérifié AVANT création/modification
      condition     = data.aws_ami.ubuntu.architecture == "x86_64"
      error_message = "L'AMI doit être en x86_64."
    }
    postcondition {                              # vérifié APRÈS ; self = la ressource
      condition     = self.public_ip != ""
      error_message = "L'instance doit avoir une IP publique."
    }
  }
}
```
Points de vigilance :

- `create_before_destroy` impose que l'ancien et le nouveau objets **coexistent** : si un nom est unique (bucket, DNS), le remplacement échoue. Utilisez `name_prefix` ou un suffixe aléatoire. Cette option **se propage** aux dépendances.
- `prevent_destroy` est un filet de sécurité *dans le code* : supprimer le bloc ou le commentaire suffit à contourner. La vraie protection est la protection côté cloud (*deletion protection*, politiques IAM, verrous de ressource).
- `ignore_changes = all` est un anti-pattern : vous renoncez à gérer la ressource.
- `precondition` valide les **hypothèses** (entrées, data sources) ; `postcondition` valide le **résultat**. Elles produisent des messages d'erreur métier bien plus clairs qu'une erreur d'API.

### Provisioners : à éviter
`provisioner "local-exec"` ou `remote-exec` exécutent des commandes à la création. HashiCorp les qualifie de **dernier recours** : non déclaratifs, non rejoués, difficiles à déboguer. Préférez `user_data`/cloud-init, des images Packer, ou un outil dédié (Ansible). En cas de besoin, `terraform_data` + `triggers_replace` rend l'exécution au moins contrôlable.

### Meta-arguments : récapitulatif
| Meta-argument | S'applique à | Rôle |
|---------------|--------------|------|
| `count` | resource, module, data | N copies indexées par nombre |
| `for_each` | resource, module, data | une copie par clé de map/set |
| `provider` | resource, data | choisir une configuration de provider (alias) |
| `depends_on` | resource, module, data | dépendance explicite |
| `lifecycle` | resource | politique de création/destruction |

### Pièges supplémentaires
- Une `data source` lue pendant le plan avec une valeur encore inconnue est **différée** à l'apply : le plan affiche alors moins de détails.
- `timestamp()`, `uuid()` provoquent un « changement » à chaque plan : à bannir dans les arguments de ressources.
- Les noms de ressources (`resource "x" "nom"`) n'ont pas à être uniques entre types, mais **doivent l'être par type** dans un module.

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
