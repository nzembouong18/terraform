# Sécurité : synthèse

Voir le module détaillé : [03-avance/13-securite](../03-avance/13-securite/README.md) et la politique : [04-expert/16-policy-as-code](../04-expert/16-policy-as-code/README.md).

## Checklist « avant de merger »
- [ ] Aucun secret dans le code, les `.tfvars`, les outputs, les logs de CI
- [ ] Backend chiffré + versionné + accès restreint
- [ ] Authentification CI par OIDC, rôles à moindre privilège (plan ≠ apply)
- [ ] `checkov`/`trivy` sans finding critique non justifié
- [ ] Ressources critiques protégées (`prevent_destroy`, deletion protection)
- [ ] Chiffrement au repos et en transit ; IMDSv2 ; accès public bloqué
- [ ] Security Groups : pas de `0.0.0.0/0` entrant hors ports publics volontaires
- [ ] Tags de propriétaire/environnement ; journalisation (CloudTrail/Config) active
- [ ] Providers/modules épinglés ; lock file à jour

## Les cinq domaines de sécurité d'un projet Terraform

### 1. Identités et accès
- La CI s'authentifie par **OIDC** (pas de clé longue durée) ; deux rôles : *plan* (lecture) et *apply* (écriture, environnement protégé).
- Les humains n'appliquent pas en production ; accès d'urgence (*break glass*) journalisé et limité dans le temps.
- Le rôle de Terraform n'est **jamais** administrateur global : bornes de permissions (*permission boundaries*, SCP, Azure Policy, Org Policy).

### 2. Secrets
| Où ? | Règle |
|------|-------|
| Code, `.tfvars` versionnés | jamais de secret |
| Variables d'environnement `TF_VAR_*` | acceptable, injectées par la CI depuis un coffre |
| Outputs | pas de secret ; `sensitive = true` ne protège pas le state |
| State | contient des secrets : chiffrement + accès restreint |
| Valeurs `ephemeral` / `*_wo` | à privilégier dès que le provider les propose |

### 3. State et plans
- Backend chiffré (KMS), versionné, journalisé, accès IAM minimal, pas d'accès public.
- Les **fichiers de plan** contiennent aussi des secrets : artefacts privés, durée de vie courte.
- Lecture du state ≈ lecture des secrets ; écriture du state ≈ capacité à détruire ou rediriger l'infrastructure.

### 4. Chaîne d'approvisionnement
- Providers : versions bornées + lock file multi-plateformes ; vérification de signature par `init`.
- Modules : tag/SHA épinglé, registry interne, revue des mises à jour (Renovate/Dependabot).
- Actions de CI épinglées par SHA ; pas de secrets exposés aux PR provenant de forks.
- Un `plan` exécute du code tiers (providers, data sources `external`) : exécuter les plans non fiables dans un runner isolé.

### 5. Conformité de l'infrastructure produite
- Analyse statique du code (Checkov, Trivy, tflint) **et** politiques sur le plan (OPA/Sentinel).
- Contrôles continus côté cloud (AWS Config, Azure Policy, Security Command Center) pour ce qui est modifié hors Terraform.
- Détection de dérive planifiée ; inventaire des ressources non gérées par Terraform.

## Correspondance avec des référentiels
| Besoin de conformité | Contrôle Terraform correspondant |
|----------------------|----------------------------------|
| Traçabilité des changements (ISO 27001, SOC 2) | PR obligatoires, historique Git, plans archivés, journaux CI |
| Séparation des tâches | rôles distincts plan/apply, approbation par un tiers |
| Chiffrement des données (RGPD, PCI-DSS) | KMS/SSE obligatoires par défaut dans les modules, politiques qui refusent l'absence de chiffrement |
| Gestion des accès | OIDC, moindre privilège, revue périodique des rôles |
| Gestion des vulnérabilités | mises à jour automatiques de providers/modules, analyse statique |
| Continuité (PRA) | état répliqué, sauvegardes, procédure de reconstruction testée |

## Que faire en cas d'incident ?
1. **Contenir** : révoquer le secret ou le rôle compromis.
2. **Évaluer** : journaux d'accès au state, journaux d'audit cloud (CloudTrail, Activity Log, Audit Logs).
3. **Éradiquer** : régénérer les secrets présents dans le state (`-replace`), corriger l'erreur de configuration à l'origine.
4. **Rétablir** : `plan` sans changement inattendu, restaurer le state depuis la version saine si nécessaire.
5. **Apprendre** : post-mortem sans recherche de coupable, nouvelle règle de politique ou de test pour que ce cas ne se reproduise pas.
