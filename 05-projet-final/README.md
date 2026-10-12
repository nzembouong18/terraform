# 🏁 Projet final — Plateforme web sur AWS (dev + prod)

Capstone qui mobilise tout le parcours : modules, `for_each`, `dynamic`, backend S3, environnements, tests, sécurité, CI.

```
Internet ─► ALB (subnets publics) ─► ASG nginx (subnets privés) ─► NAT ─► Internet
                         VPC multi-AZ (2 zones en dev, 3 en prod)
```

```
05-projet-final/
├── modules/
│   ├── reseau/        # VPC, subnets, IGW, NAT (1 ou 1/zone), routes + tests (provider simulé)
│   └── application/   # SG, ALB, launch template (IMDSv2, EBS chiffré), ASG
└── envs/
    ├── dev/           # 2 zones, 1 NAT, capacité 1..2
    └── prod/          # 3 zones, 1 NAT/zone, capacité 2..6
```

## Cahier des charges (à réaliser par l'apprenant)
Reprenez le code comme **base** et complétez :

1. **Backend** : créez le bucket d'état (module 15) et initialisez : `terraform init -backend-config=backend.hcl` (copiez `backend.hcl.example`).
2. **HTTPS** : ajoutez un certificat ACM + listener 443 + redirection 80→443 (variable `domaine`, `count` conditionnel).
3. **Base de données** : module `donnees` (RDS PostgreSQL, subnets privés, mot de passe via **valeur éphémère/write-only** ou Secrets Manager — jamais en clair dans le code).
4. **Observabilité** : alarme CloudWatch sur la 5xx de l'ALB + topic SNS.
5. **Autoscaling** : politique de *target tracking* sur le CPU.
6. **Tests** : `terraform test` pour `application` (provider simulé) ; un test d'intégration sur `reseau`.
7. **Politique** : règles OPA du module 16 appliquées au plan.
8. **CI** : pipeline du module 12 (OIDC, plan sur PR, apply sur `main` après approbation).
9. **Coûts** : estimation `infracost` ; justifiez la différence dev/prod.
10. **Exploitation** : documentez la procédure de montée de version d'AMI (`instance_refresh`) et de restauration du state.

## Validation sans compte AWS
```bash
cd modules/reseau && terraform init -backend=false && terraform test      # 3 tests, provider simulé
cd ../../envs/dev && terraform init -backend=false && terraform validate
```
## Déploiement réel (coûts : NAT + ALB ≈ quelques € par jour — **détruire après usage**)
```bash
cd envs/dev && cp backend.hcl.example backend.hcl   # adapter le bucket
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan && terraform apply tfplan
curl $(terraform output -raw url)
terraform destroy
```

## Grille d'évaluation
| Critère | Points |
|---------|-------|
| Code propre, modules cohérents, variables validées | 20 |
| Sécurité (chiffrement, moindre privilège, pas de secrets) | 20 |
| Tests (unitaires + intégration) | 15 |
| CI/CD et politiques | 15 |
| Gestion d'état/environnements | 15 |
| Documentation et exploitation | 15 |
