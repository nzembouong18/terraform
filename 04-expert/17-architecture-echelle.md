# 17 — Architecture et passage à l'échelle

## 1. Découpage des états (blast radius)
```
00-bootstrap/        # bucket d'état, rôles OIDC (créés une fois, à la main/CLI)
10-reseau/           # VPC, subnets, DNS         ─ change rarement
20-plateforme/       # EKS/ECS, bases de données ─ change parfois
30-applications/     # services                  ─ change souvent
modules/             # modules versionnés
envs/{dev,recette,prod}/
```
Règles : un état **par couche × environnement** ; les couches basses ne dépendent jamais des hautes ; les échanges passent par des **outputs** (remote state, SSM, data sources par tags).

## 2. Orchestration DRY
| Approche | Principe | Quand |
|----------|----------|-------|
| Dossiers + modules | duplication minimale de « glue » | petites/moyennes équipes |
| **Terragrunt** | génère backend/providers, `dependency`, `run-all` | beaucoup d'états/comptes |
| **HCP Terraform Stacks** | déploiements multi-états/régions déclaratifs (`.tfstacks.hcl`) | écosystème HCP |
| Workspaces HCP + variable sets | unité = workspace | gouvernance centralisée |
| **OpenTofu** | fork open source compatible (chiffrement du state natif, `for_each` sur providers) | contraintes de licence |

## 3. Dérive et cohérence
- **Détecter** : `plan -detailed-exitcode` planifié ; HCP « health assessments ».
- **Corriger** : par défaut on **ré-applique** le code (source de vérité) ; si le changement manuel est légitime → le coder.
- **Empêcher** : droits en écriture manuels retirés ; SCP/IAM ; politiques.
- `ignore_changes` : uniquement pour les attributs légitimement gérés ailleurs (autoscaling).

## 4. Performance
- `-parallelism=N` (défaut 10) ; attention aux limites d'API (429).
- `-target` : **dépannage uniquement**, jamais un workflow normal (laisse le state incohérent).
- `-refresh=false` pour un plan rapide (au prix de la détection de dérive) ; `-lock-timeout=5m`.
- États trop gros (> 500–1000 ressources) = plans lents → scinder (`moved` + `state mv` / `removed` + `import`).
- Cache de providers : `TF_PLUGIN_CACHE_DIR=~/.terraform.d/plugin-cache`.

## 5. Internals à connaître
- **Walk du graphe** : *plan* → *apply* ; les noeuds : ressources, providers, variables, outputs, modules, « expansion » (count/for_each).
- Valeurs *unknown* (« known after apply ») : propagées dans le plan ; interdites dans `count`/`for_each` clés.
- `terraform graph`, `terraform console`, `TF_LOG=TRACE`.
- Verrou d'état + sérialisation (`serial`, `lineage` dans le state) : détection de conflit d'écriture.
- Le state est un JSON versionné : **ne jamais l'éditer à la main** ; utiliser `state mv/rm`, `moved`, `import`, `removed`.

## 6. Gouvernance et FinOps
- Policies (module 16), `tflint`/`checkov` en CI, tags obligatoires (`default_tags`).
- **Infracost** (estimation de coût dans la PR), budgets, tags de coût.
- Registry privée de modules + SemVer + catalogue « golden paths » (ex. `terraform-aws-web-app`).
- Revue d'**impact** : le plan est le livrable de la PR (commentaire automatique).

## 7. Stratégie de montée de version
1. Lire le *CHANGELOG* et les guides d'upgrade du provider (majeures : 4→5→6).
2. Branche dédiée, `terraform init -upgrade`, plan **sans changement attendu**.
3. Épingler (`~>`) puis avancer progressivement ; automatiser avec Renovate.
4. Terraform core : respecter la compatibilité du state (on ne revient pas en arrière après un apply avec une version plus récente).

## Ateliers
1. **Refonte** : partez de [`05-projet-final`](../05-projet-final) et découpez-le en 2 états (`reseau`, `application`) reliés par `terraform_remote_state` ; migrez le state **sans détruire** (`state mv` vers un nouvel état ou `removed`+`import`).
2. **Dérive** : créez un workflow cron qui exécute `plan -detailed-exitcode` et ouvre une issue en cas de dérive.
3. **Terragrunt** : réécrivez `envs/dev` et `envs/prod` avec un `terragrunt.hcl` racine qui génère backend et provider.
4. **Revue d'architecture** : pour 3 équipes, 5 comptes AWS et 3 environnements, proposez le découpage, la stratégie d'identités, le flux de PR et les garde-fous. Justifiez les compromis.
5. **Incident** : le state d'une prod est verrouillé depuis 3 h et un `apply` a été interrompu : décrivez la procédure (vérifier le runner, `force-unlock`, `plan`, réparation des écarts, post-mortem).
