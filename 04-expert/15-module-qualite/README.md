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
variable "versioning" { type = bool  default = true }
resource "aws_s3_bucket_lifecycle_configuration" "versions" {
  count = var.versioning && var.retention_jours_versions > 0 ? 1 : 0
}
```
Préférez des **objets** pour grouper des options liées plutôt que 30 variables plates ; gardez les outputs stables (ils font partie du contrat).

## Publication
- Git tags (`?ref=v1.0.0`) pour usage interne simple.
- Registry privée (HCP Terraform, Artifactory, GitLab) : `source = "app.terraform.io/mon-org/s3/aws"`.
- Registry publique : nom de dépôt `terraform-<PROVIDER>-<NOM>`, tags SemVer.

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
