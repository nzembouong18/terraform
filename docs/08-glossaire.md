# Glossaire

Définitions des notions rencontrées dans le parcours, avec le module où elles sont approfondies.

## Fondamentaux
| Terme | Définition | Module |
|-------|-----------|:------:|
| **IaC (Infrastructure as Code)** | Décrire l'infrastructure dans des fichiers versionnés, relus et rejouables plutôt que de la configurer à la main | 01 |
| **Déclaratif** | On décrit l'état **souhaité** ; l'outil calcule les actions pour y parvenir (opposé : impératif) | 01 |
| **Idempotence** | Appliquer plusieurs fois la même configuration donne le même résultat | 01 |
| **HCL** | *HashiCorp Configuration Language* : syntaxe en blocs, arguments et expressions | 01 |
| **Core (cœur)** | Binaire `terraform` : analyse le HCL, construit le graphe, calcule le plan, gère le state | 01 |
| **Provider** | Plugin (binaire, gRPC) qui traduit les ressources en appels d'API d'un service | 01 |
| **Registry** | Catalogue de providers et de modules (`registry.terraform.io`, privé, miroir) | 01, 06 |
| **Lock file** | `.terraform.lock.hcl` : versions exactes et hash des providers, à versionner | 01 |
| **Contrainte de version** | `=`, `>=`, `~>` : plage de versions acceptées pour Terraform, un provider ou un module | 01 |
| **Module racine / enfant** | Le dossier où l'on exécute Terraform / un module appelé par un autre | 06 |

## Le langage
| Terme | Définition | Module |
|-------|-----------|:------:|
| **Resource** | Objet géré (créé, modifié, détruit) par Terraform | 03 |
| **Data source** | Lecture d'un objet existant, sans le gérer | 03 |
| **Argument / attribut** | Entrée que l'on fournit / valeur lisible après création (arguments + valeurs calculées) | 03 |
| **Variable** | Entrée d'un module, typée, validable, éventuellement sensible | 02 |
| **Local** | Valeur calculée interne à un module (non surchargeable) | 02 |
| **Output** | Sortie exposée à l'utilisateur, à un module parent ou à une autre stack | 02 |
| **Type complexe** | `list`, `set`, `map`, `object`, `tuple` ; `optional()` rend un champ d'un objet facultatif | 02 |
| **Expression `for`** | Transforme ou filtre une collection : `[for x in l : f(x)]`, `{for k,v in m : k => v}` | 05 |
| **Splat** | Raccourci `res[*].attr` pour extraire un attribut de chaque instance | 02 |
| **`count`** | Meta-argument qui crée N instances indexées par un entier | 05 |
| **`for_each`** | Meta-argument qui crée une instance par clé d'une map/d'un set | 05 |
| **`dynamic`** | Bloc qui génère des blocs imbriqués répétés | 05 |
| **`depends_on`** | Dépendance explicite, pour un lien invisible dans le code | 03 |
| **`lifecycle`** | Politique de cycle de vie : `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`, conditions | 03 |
| **Precondition / postcondition** | Contrats vérifiés avant / après la création d'une ressource | 03 |
| **Validation** | Condition sur une variable, vérifiée dès l'évaluation | 02 |
| **Check** | Assertion **non bloquante** (avertissement) évaluée en fin de plan/apply | 10 |
| **Valeur inconnue** | `(known after apply)` : valeur qui ne sera connue qu'après la création | 05 |
| **Interpolation** | Insertion d'une expression dans une chaîne : `"${var.nom}-x"` | 02 |
| **Heredoc** | Chaîne multi-lignes `<<-EOT … EOT` | 01 |
| **Template** | Fichier texte rendu par `templatefile` (directives `%{ }`) | 09 |

## Exécution et état
| Terme | Définition | Module |
|-------|-----------|:------:|
| **Plan** | Liste d'actions calculée en comparant code, state et réalité | 01 |
| **Apply** | Exécution des actions du plan, puis écriture du state | 01 |
| **Graphe de dépendances** | Graphe orienté acyclique des objets ; détermine l'ordre et le parallélisme | 03 |
| **State** | Correspondance entre le code et les objets réels (+ attributs, dépendances) | 04 |
| **`serial` / `lineage`** | Compteur de modifications / identifiant unique d'un state (détection de conflits) | 04 |
| **Backend** | Où le state est stocké et comment il est verrouillé | 07 |
| **Lock (verrou)** | Empêche deux opérations simultanées sur le même state | 07 |
| **Remote state** | State distant ; `terraform_remote_state` lit les **outputs** d'une autre stack | 07 |
| **Drift (dérive)** | Écart entre l'infrastructure réelle et le state/le code | 04 |
| **Refresh** | Mise à jour du state depuis la réalité (`-refresh-only`) | 04 |
| **Taint / replace** | Marquer une ressource à recréer (`apply -replace=ADDR`) | 04 |
| **Resource address** | Chemin unique d'une instance : `module.m.aws_x.n["k"]` | 04 |
| **Workspace (CLI)** | State supplémentaire pour la même configuration | 08 |
| **Workspace (HCP)** | Unité de gestion : state + variables + permissions + historique de runs | 08 |
| **Configuration partielle** | Backend dont certaines valeurs sont passées à l'init (`-backend-config`) | 07 |

## Évolution et refactoring
| Terme | Définition | Module |
|-------|-----------|:------:|
| **`moved`** | Bloc déclaratif qui change l'adresse d'une ressource **sans** la détruire | 11 |
| **`import`** | Bloc/commande qui rattache un objet existant à une ressource du code | 11 |
| **`removed`** | Bloc qui sort une ressource du state, avec ou sans destruction | 11 |
| **`state mv/rm`** | Commandes impératives de chirurgie du state (dernier recours) | 11 |
| **`-target`** | Limiter une opération à certaines ressources (diagnostic uniquement) | 03, 17 |
| **SemVer** | Versionnement `MAJOR.MINOR.PATCH` d'un module | 15 |

## Qualité et sécurité
| Terme | Définition | Module |
|-------|-----------|:------:|
| **`terraform test`** | Framework natif de tests (`*.tftest.hcl`) | 10 |
| **Mock provider** | Provider simulé pour tester sans credentials | 10 |
| **Linting** | Analyse statique de conventions et d'erreurs (tflint) | 13 |
| **Policy as code** | Règles de conformité exécutables sur le plan (OPA/Rego, Sentinel) | 16 |
| **Rego** | Langage déclaratif d'OPA | 16 |
| **Sentinel** | Langage de politiques de HashiCorp (HCP/Enterprise) | 16 |
| **Sensitive** | Marque une valeur à masquer à l'affichage (mais **pas** du state) | 02, 13 |
| **Ephemeral** | Valeur non persistée dans le state ni le plan (≥ 1.10) | 13 |
| **Write-only** | Argument de ressource jamais stocké dans le state (≥ 1.11) | 13 |
| **OIDC** | Fédération d'identité : la CI obtient des identifiants temporaires sans secret stocké | 12 |
| **Moindre privilège** | N'accorder que les droits nécessaires, sur la portée la plus étroite | 13 |
| **Supply chain** | Chaîne d'approvisionnement (providers, modules, actions CI) à épingler et vérifier | 13 |

## Architecture et exploitation
| Terme | Définition | Module |
|-------|-----------|:------:|
| **Blast radius** | Périmètre d'impact potentiel d'une erreur | 17 |
| **Couche (layer)** | Niveau d'architecture (réseau, plateforme, applications) avec son propre state | 17 |
| **Golden path** | Chemin balisé et sécurisé proposé aux équipes (modules « produit ») | 17 |
| **Landing zone** | Socle multi-comptes préconfiguré (comptes, journalisation, garde-fous) | 17 |
| **Terragrunt** | Surcouche qui génère backend/providers et orchestre plusieurs états | 17 |
| **Stacks (HCP)** | Orchestration déclarative de composants multi-états/régions | 17 |
| **Alias de provider** | Seconde configuration d'un même provider (autre région/compte) | 14 |
| **`default_tags`** | Tags appliqués automatiquement par le provider AWS | 14 |
| **HCP Terraform** | Service SaaS HashiCorp (state, runs, politiques) ; ex-Terraform Cloud | 12 |
| **OpenTofu** | Fork open source de Terraform (Linux Foundation, MPL 2.0), CLI `tofu` | docs/07 |
| **Infracost** | Estimation des coûts d'un plan dans la PR | 17 |
| **ADR** | *Architecture Decision Record* : trace d'une décision d'architecture | — |
| **Runbook** | Procédure d'exploitation pas à pas (restauration du state, montée de version) | — |
