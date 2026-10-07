# Parcours de formation et évaluation

## Vue d'ensemble (≈ 60 h de formation, 8 à 12 semaines à mi-temps)

| Niveau | Contenu | Durée | Livrable |
|--------|---------|-------|----------|
| 🟢 1 Débutant | workflow, HCL, variables, ressources, state | 6 h 30 | labs 01–04 + quiz niveau 1 |
| 🟡 2 Intermédiaire | boucles, modules, backends, environnements, fonctions | 9 h 30 | labs 05–09 + quiz niveau 2 |
| 🟠 3 Avancé | tests, refactoring/import, CI/CD, sécurité | 8 h | labs 10–13 + quiz niveau 3 |
| 🔴 4 Expert | multi-région, modules « registry », policies, architecture, providers | 12 h | labs 14–18 + quiz niveau 4 |
| 🏁 Projet | plateforme AWS dev/prod complète | 15–20 h | dépôt + soutenance |

### Planning type (rythme mi-temps, 1 module par séance de 2–3 h)
| Semaine | Modules |
|---------|---------|
| 1 | 01, 02 |
| 2 | 03, 04 |
| 3 | 05, 06 |
| 4 | 07, 08, 09 |
| 5 | 10, 11 |
| 6 | 12, 13 |
| 7 | 14, 15 |
| 8 | 16, 17, 18 |
| 9–10 | Projet final |
| 11 | Révisions + [quiz](09-quiz.md) + [préparation certification](06-certification.md) |

## Méthode pédagogique
1. **Lire** le cours du module (15–30 min).
2. **Pratiquer** les exercices dans un dossier `exercice/` (sans regarder `solution/`).
3. **Comparer** avec `solution/` ; exécuter `terraform plan` sur le corrigé pour voir les différences.
4. **Casser** volontairement (variable invalide, ressource supprimée à la main) et lire les erreurs.
5. **Expliquer** à voix haute (ou par écrit) ce que fait le plan : c'est le meilleur indicateur de maîtrise.

## Matrice de compétences (auto-évaluation : 0 = jamais vu → 3 = je sais l'enseigner)
| Compétence | Niveau attendu | 0 | 1 | 2 | 3 |
|------------|:--:|--|--|--|--|
| Workflow init/plan/apply/destroy | 1 | ☐ | ☐ | ☐ | ☐ |
| Lire un plan et prévoir son impact | 1 | ☐ | ☐ | ☐ | ☐ |
| Variables typées, validation, locals, outputs | 1 | ☐ | ☐ | ☐ | ☐ |
| Dépendances, data sources, lifecycle | 1 | ☐ | ☐ | ☐ | ☐ |
| State : inspecter, `moved`, drift | 1–2 | ☐ | ☐ | ☐ | ☐ |
| `count`, `for_each`, `for`, `dynamic` | 2 | ☐ | ☐ | ☐ | ☐ |
| Concevoir/consommer des modules | 2 | ☐ | ☐ | ☐ | ☐ |
| Backends distants, verrouillage, remote state | 2 | ☐ | ☐ | ☐ | ☐ |
| Stratégie multi-environnements | 2 | ☐ | ☐ | ☐ | ☐ |
| `terraform test`, mocks | 3 | ☐ | ☐ | ☐ | ☐ |
| Import, refactoring sans destruction | 3 | ☐ | ☐ | ☐ | ☐ |
| Pipeline CI/CD, OIDC, garde-fous | 3 | ☐ | ☐ | ☐ | ☐ |
| Gestion des secrets, state sécurisé | 3 | ☐ | ☐ | ☐ | ☐ |
| Providers multiples/alias, multi-compte | 4 | ☐ | ☐ | ☐ | ☐ |
| Modules de qualité publiables | 4 | ☐ | ☐ | ☐ | ☐ |
| Policy as code | 4 | ☐ | ☐ | ☐ | ☐ |
| Architecture à l'échelle, dérive, performance | 4 | ☐ | ☐ | ☐ | ☐ |
| Comprendre le fonctionnement interne d'un provider | 4 | ☐ | ☐ | ☐ | ☐ |

**Profil « équilibré »** = ≥ 2 partout jusqu'au niveau 3, et ≥ 1 sur le niveau 4 avec **un** sujet d'approfondissement à 3 (modules, CI/CD, sécurité *ou* architecture).

## Évaluation certifiante interne
- **Niveau 1 → 3** : 80 % au quiz + labs exécutés.
- **Projet final** : grille de la [page du projet](../05-projet-final/README.md) ≥ 70/100.
- **Oral** (30 min) : défendre une décision d'architecture (découpage d'états, stratégie d'environnements, gestion des secrets).
