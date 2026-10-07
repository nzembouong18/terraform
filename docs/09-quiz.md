# Quiz d'auto-évaluation

Répondez d'abord, puis dépliez les réponses. Seuil de réussite conseillé : 80 %.

## 🟢 Niveau 1
1. Quelle commande calcule les changements sans rien modifier ?
2. Que contient le state et pourquoi ne faut-il pas le committer ?
3. Que signifie `-/+` dans un plan ? Donnez un cas.
4. Différence entre une variable `locals` et `variable` ?
5. Quand utiliser `depends_on` ?
6. Quelle est la différence entre `resource` et `data` ?
7. Que fait `terraform state rm` ? Détruit-il la ressource réelle ?
8. Ordre de priorité : `TF_VAR_x`, `-var`, `terraform.tfvars` ?
9. `~> 5.1` accepte quelles versions ?
10. À quoi sert `.terraform.lock.hcl` ?

<details><summary>Réponses</summary>

1. `terraform plan`.
2. Identifiants, attributs de toutes les ressources, parfois des secrets en clair → fuite.
3. Remplacement (destroy puis create) ; ex. changement d'un argument « ForceNew » (nom d'une instance, AMI…).
4. `variable` = entrée externe ; `locals` = valeur calculée interne.
5. Dépendance **non exprimée** par une référence (ex. politique IAM requise avant usage).
6. `resource` gère (crée/modifie/détruit) ; `data` lit uniquement.
7. Retire du state ; la ressource réelle **reste** (Terraform ne la gère plus).
8. `TF_VAR_x` < `terraform.tfvars` < `-var` (la ligne de commande gagne).
9. ≥ 5.1.0 et < 6.0.0.
10. Fige les versions et empreintes des providers (reproductibilité/sécurité).
</details>

## 🟡 Niveau 2
1. Pourquoi préférer `for_each` à `count` sur une liste de noms ?
2. Qu'est-ce qu'un `dynamic` block ?
3. Que produit `cidrsubnet("10.0.0.0/16", 8, 3)` ?
4. Comment un module reçoit-il un provider avec alias ?
5. Qu'est-ce que `terraform_remote_state` expose ?
6. Risque principal des workspaces CLI pour la prod ?
7. Comment passer un backend en configuration partielle ?
8. Que signifie « known after apply » et quel impact sur `for_each` ?
9. Différence entre `try()` et `can()` ?
10. Que fait `init -migrate-state` ?

<details><summary>Réponses</summary>

1. Retirer un élément du milieu avec `count` décale les index → recréations ; `for_each` utilise des clés stables.
2. Génère dynamiquement des blocs imbriqués répétés à partir d'une collection.
3. `10.0.3.0/24`.
4. Via `providers = { aws.alias = aws.autre }` dans l'appel + `configuration_aliases` dans le module.
5. Uniquement les **outputs** racine de l'autre état.
6. Même backend/credentials → isolation faible ; erreur de workspace = impact en prod.
7. `backend "s3" {}` vide + `-backend-config=fichier|clé=valeur` à l'init.
8. Valeur connue seulement à l'apply ; ne peut pas servir de clé de `for_each`/valeur de `count`.
9. `try` retourne la première expression sans erreur (ou un défaut) ; `can` retourne un booléen.
10. Copie le state existant vers le nouveau backend.
</details>

## 🟠 Niveau 3
1. Différence entre `command = plan` et `command = apply` dans `terraform test` ?
2. À quoi sert `mock_provider` ?
3. Comment renommer une ressource sans la détruire ?
4. Procédure d'adoption d'une ressource existante avec le bloc `import` ?
5. Pourquoi `terraform apply tfplan` en CI ?
6. Que protège (et ne protège pas) `sensitive = true` ?
7. Que fait `plan -detailed-exitcode` (codes) ?
8. Pourquoi l'OIDC plutôt que des clés d'accès dans la CI ?
9. Qu'apporte `removed { lifecycle { destroy = false } }` ?
10. Différence entre `precondition` et `validation` d'une variable ?

<details><summary>Réponses</summary>

1. `plan` n'évalue que le plan (rapide, rien créé) ; `apply` crée réellement puis détruit à la fin du fichier.
2. Simuler un provider : tests unitaires sans credentials ni coût.
3. Bloc `moved { from, to }`.
4. `import { to, id }` → `plan -generate-config-out` → nettoyer → `plan` à 0 changement → apply → retirer le bloc.
5. Appliquer **exactement** le plan relu ; pas de dérive entre plan et apply.
6. Masque l'affichage CLI ; **pas** le state ni le plan sauvegardé.
7. `0` rien à faire, `1` erreur, `2` changements.
8. Jetons éphémères, pas de secret longue durée à stocker/rotater, restriction par dépôt/branche.
9. Sortir une ressource du state sans la détruire (déclaratif).
10. `validation` : contrôle une entrée ; `precondition` : contrôle une hypothèse dans une ressource/data/output avant sa création, avec accès à d'autres objets.
</details>

## 🔴 Niveau 4
1. Pourquoi ne configure-t-on pas de provider dans un module ?
2. Citez 3 critères d'un module « de qualité production ».
3. Comment segmenter les états d'une grande plateforme ?
4. À quoi sert `-target` et pourquoi est-ce risqué en routine ?
5. Comment appliquer une policy OPA à Terraform ?
6. Comment détecter la dérive en continu ?
7. Quelle est la différence entre valeurs éphémères et attributs write-only ?
8. Que contient `resource_changes[].change.actions` ?
9. Comment migrer sans destruction une ressource vers un autre état ?
10. Quel est le rôle du protocole gRPC entre Terraform et un provider ?

<details><summary>Réponses</summary>

1. Sinon on ne peut plus détruire le module (provider disparu en même temps) ; la config appartient au racine.
2. Sécurité par défaut, API minimale validée, tests, exemples, SemVer + `moved`, docs, providers bornés.
3. Par couche (réseau/plateforme/apps) × environnement ; liens par outputs.
4. Limiter un plan/apply à certaines ressources ; laisse le reste incohérent, contourne le graphe complet.
5. `terraform show -json tfplan` → `opa eval`/`conftest` (ou policies HCP/Sentinel) dans la CI.
6. `plan -detailed-exitcode` planifié (code 2 = écart) + alerte ; health assessments HCP.
7. Éphémère : valeur jamais persistée (variables, ressources `ephemeral`) ; write-only : argument d'une ressource non stocké dans le state.
8. `create`, `read`, `update`, `delete`, `no-op` (combinaisons pour un remplacement).
9. `removed { destroy = false }` dans l'ancien état + `import` dans le nouveau (ou `state mv -state-out`).
10. Communication core ⇄ provider : schéma, validation, plan, apply, read, import.
</details>
