# 15 — Concevoir un module de qualité « registry »

Un bon module est un **produit** : API stable, sécurisé par défaut, testé, documenté, versionné.

## Checklist
- [ ] **Interface minimale** : peu de variables obligatoires, types précis, `description` partout, `validation`.
- [ ] **Sécurité par défaut** : chiffrement, accès public bloqué, TLS obligatoire — on *ouvre* explicitement, on ne *ferme* pas.
- [ ] **Pas de provider configuré**, versions bornées (`>= 5.40, < 6.0`).
- [ ] **Outputs** complets (`id`, `arn`, `name`).
- [ ] **`examples/`** exécutables = documentation + cible des tests d'intégration.
- [ ] **Tests** : `terraform test` + mocks (sans credentials) ; intégration optionnelle.
- [ ] **Docs** générées (`terraform-docs markdown table . > README.md`).
- [ ] **SemVer** : `MAJOR` (rupture : variable supprimée/renommée, ressource recréée), `MINOR` (fonctionnalité compatible), `PATCH` (correctif). Tags `v1.2.3`, `CHANGELOG`.
- [ ] **Compatibilité** : `moved` blocks pour les renommages internes → pas de destruction chez les consommateurs.

## Feature toggles & bonnes pratiques d'API
```hcl
variable "versioning" {
  type = bool
  default = true
}
resource "aws_s3_bucket_lifecycle_configuration" "versions" {
  count = var.versioning && var.retention_jours_versions > 0 ? 1 : 0
}
```
Préférez des **objets** pour grouper des options liées plutôt que 30 variables plates ; gardez les outputs stables (ils font partie du contrat).

## Publication
- Git tags (`?ref=v1.0.0`) pour usage interne simple.
- Registry privée (HCP Terraform, Artifactory, GitLab) : `source = "app.terraform.io/mon-org/s3/aws"`.
- Registry publique : nom de dépôt `terraform-<PROVIDER>-<NOM>`, tags SemVer.

## Comprendre en profondeur

### Un module est une API
Les variables et outputs forment un **contrat** avec ses consommateurs. Le casser (renommer une variable, changer le type d'un output, recréer une ressource) oblige tout le monde à adapter son code. Concevoir l'interface d'abord, l'implémentation ensuite : *quelles décisions le consommateur doit-il prendre ? lesquelles le module prend-il pour lui ?*

Principe directeur : **opinionated** sur la sécurité et les conventions, **souple** sur ce qui varie réellement d'un usage à l'autre.

### Concevoir les variables
```hcl
variable "chiffrement" {
  description = "Chiffrement SSE. Par défaut : clé gérée AWS ; fournir `kms_key_arn` pour une clé client."
  type = object({
    activer     = optional(bool, true)
    kms_key_arn = optional(string)
  })
  default = {}
  validation {
    condition     = var.chiffrement.activer || var.chiffrement.kms_key_arn == null
    error_message = "kms_key_arn n'a de sens que si le chiffrement est activé."
  }
}
```
- Un **objet par thème** (chiffrement, journalisation, cycle de vie) plutôt que des dizaines de variables plates.
- Les **défauts sûrs** : on active le chiffrement, on bloque l'accès public ; on offre une option explicite pour l'assouplir.
- Messages d'erreur qui disent **quoi faire**, pas seulement ce qui est faux.
- Tout est documenté : `description` sur chaque variable et output.

### Sorties et stabilité
Exposez ce dont un consommateur a besoin pour composer (`id`, `arn`, `name`, endpoints), pas les objets entiers (`value = aws_s3_bucket.this` fige votre implémentation). Un output **ne se supprime pas** sans version MAJOR. Marquez `sensitive = true` les valeurs sensibles.

### Compatibilité ascendante : mode d'emploi
| Changement | Impact | Version |
|------------|--------|:------:|
| Nouvelle variable optionnelle (défaut = comportement actuel) | aucun | MINOR |
| Nouvel output | aucun | MINOR |
| Nouvelle ressource optionnelle | aucun | MINOR |
| Renommage interne **avec** `moved` | aucun | PATCH/MINOR |
| Renommage interne **sans** `moved` | destruction/recréation | **MAJOR** |
| Changement de défaut qui modifie l'infra | modification chez tous | **MAJOR** |
| Suppression d'une variable / d'un output | casse le code appelant | **MAJOR** |
| Montée de la borne minimale d'un provider | peut forcer une mise à jour | MINOR/MAJOR (documenter) |

Conservez un `CHANGELOG.md` (format *Keep a Changelog*) et un guide de migration pour chaque version majeure.

### Versions et contraintes de providers
```hcl
terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.40, < 6.0" }
  }
}
```
Un module est une bibliothèque : il exprime une **plage** de compatibilité large (`>=` avec borne haute), pas une version exacte. C'est la **racine** qui verrouille les versions via le lock file.

### Tests d'un module : stratégie
1. **Statique** : `fmt`, `validate`, `tflint`, `checkov` sur le module *et* sur `examples/`.
2. **Unitaires** (`terraform test` + `mock_provider`) : validations, conditions, nombre de ressources.
3. **Exemples exécutables** : `examples/minimal` doit se `validate` sans configuration superflue ; `examples/complet` couvre les options avancées.
4. **Intégration** (nightly) : `apply` réel dans un compte jetable, vérifications, `destroy`.
5. **Non-régression** : un test `moved` qui prouve qu'un renommage ne détruit pas.

### Documentation
- `README.md` : objectif, exemple d'usage minimal, tableaux Entrées/Sorties (générés par `terraform-docs`), prérequis (permissions, versions).
- `examples/` : code qui compile, donc **toujours à jour**.
- Section « Décisions de conception » : pourquoi tel défaut, quelles limites connues.
- Un `.terraform-docs.yml` + un hook `pre-commit` régénère le README à chaque commit.

### Pièges des modules de ressources cloud
- **Ressources scindées** : `aws_s3_bucket` + 6 ressources associées ; chacune sera créée dans le module ; choisissez lesquelles sont toujours créées et lesquelles dépendent d'une option.
- **Noms globaux uniques** : proposer `name` **ou** `name_prefix`.
- **Dépendances implicites** : un `aws_s3_bucket_policy` doit attendre le `public_access_block` (sinon erreurs intermittentes) → utiliser `depends_on` interne ciblé.
- **`count`/`for_each` conditionnels** : exposer l'output via `one()` pour éviter les erreurs lorsque la ressource n'est pas créée.
- **Taille** : un module > ~500 lignes ou > 15 variables est un candidat à la scission.

### Publier
1. Tag SemVer annoté (`git tag -a v1.0.0 -m "…"`), protection des tags.
2. Pipeline de release : tests → tag → publication (registry) → note de version générée.
3. Politique de support : quelles versions majeures reçoivent des correctifs ?
4. Dépréciation : conserver l'ancienne variable un cycle avec un avertissement (utiliser `validation` ou un output `deprecated_notice`) avant suppression à la majeure suivante.

## Exercices
1. Lancez `terraform init && terraform test` dans `solution/` : lisez chaque `run`.
2. Ajoutez la variable `logging_bucket` (optionnelle) → `aws_s3_bucket_logging` conditionnel + test.
3. Générez le README avec `terraform-docs`.
4. Ajoutez un `moved` simulant un renommage interne (`aws_s3_bucket_policy.tls_only` → `.tls`) et prouvez par un test que le plan ne détruit rien.
5. Écrivez `examples/complet` (KMS, versioning 30 j) et validez-le.
6. Lancez `checkov -d .` : corrigez/justifiez chaque finding (ex. absence de réplication → `#checkov:skip=CKV_AWS_144:raison`).
7. Défi : ajoutez un job de CI qui exécute les tests, puis tag `v1.0.0` et consommez le module depuis un autre dépôt avec `?ref=v1.0.0`.

## Corrigé
[`solution/`](solution/) (+ [`examples/minimal`](solution/examples/minimal))
