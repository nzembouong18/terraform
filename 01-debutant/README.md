# 🟢 Niveau 1 — Débutant

**Objectif :** comprendre ce qu'est l'Infrastructure as Code, maîtriser le cycle `init → plan → apply → destroy`, écrire du HCL propre et comprendre le **state**.

**Prérequis :** un terminal, Terraform ≥ 1.7 ([installation](../docs/00-installation.md)). **Aucun compte cloud** : les labs utilisent les providers `local` et `random`.

| # | Module | Durée | Vous saurez… |
|---|--------|-------|--------------|
| 01 | [Premiers pas](01-premiers-pas/README.md) | 1 h | lancer le workflow, lire un plan |
| 02 | [Variables, locals, outputs](02-variables-outputs/README.md) | 1 h 30 | paramétrer et valider une config |
| 03 | [Ressources, data, lifecycle](03-ressources-data-lifecycle/README.md) | 2 h | gérer dépendances et cycle de vie |
| 04 | [Le state](04-state/README.md) | 2 h | inspecter/réparer le state, `moved` |

Chaque dossier contient un `README.md` (cours + exercices) et un dossier `solution/` **exécutable** (à ne consulter qu'après avoir essayé !). Travaillez dans un dossier `exercice/` à côté de `solution/`.

✅ **Validation du niveau :** vous pouvez expliquer *pourquoi* un plan veut détruire une ressource, et vous savez corriger un state désynchronisé.
