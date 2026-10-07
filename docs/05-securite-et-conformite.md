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
