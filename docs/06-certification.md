# Préparation à la certification HashiCorp

> Les intitulés et objectifs d'examen évoluent : **vérifiez toujours** la page officielle (<https://developer.hashicorp.com/certifications/infrastructure-automation>) avant de vous inscrire.

| Certification | Public | Format |
|---------------|--------|--------|
| **Terraform Associate** | débutant → intermédiaire | QCM en ligne surveillé (~1 h) |
| **Terraform Authoring and Operations Professional** | avancé/expert | examen pratique en laboratoire |

## Correspondance objectifs ↔ modules

| Thème d'examen | Où le travailler |
|----------------|------------------|
| Concepts IaC, avantages de Terraform | [01](../01-debutant/01-premiers-pas/README.md) |
| Workflow principal (`init/plan/apply/destroy`, `fmt`, `validate`) | [01](../01-debutant/01-premiers-pas/README.md) |
| Providers, versions, lock file | [01](../01-debutant/01-premiers-pas/README.md), [bonnes pratiques](03-bonnes-pratiques.md) |
| Variables, outputs, locals, types, validation | [02](../01-debutant/02-variables-outputs/README.md) |
| Ressources, data, dépendances, lifecycle | [03](../01-debutant/03-ressources-data-lifecycle/README.md) |
| State, backends, verrouillage, drift | [04](../01-debutant/04-state/README.md), [07](../02-intermediaire/07-backends-remote-state/README.md) |
| `count`, `for_each`, `dynamic`, expressions | [05](../02-intermediaire/05-boucles-conditions/README.md) |
| Modules (registry, sources, versions) | [06](../02-intermediaire/06-modules/README.md), [15](../04-expert/15-module-qualite/README.md) |
| Fonctions, templates | [09](../02-intermediaire/09-fonctions-templates/README.md) |
| Workspaces | [08](../02-intermediaire/08-workspaces-environnements/README.md) |
| Import, `moved`, refactoring, chirurgie du state | [11](../03-avance/11-refactoring/README.md) |
| Tests, validations, `check` | [10](../03-avance/10-tests/README.md) |
| Secrets, sécurité, état sensible | [13](../03-avance/13-securite/README.md) |
| HCP Terraform (workspaces, runs, policies, variable sets) | [12](../03-avance/12-ci-cd/README.md), [17](../04-expert/17-architecture-echelle.md) |
| Opérations à l'échelle, dérive, performance | [17](../04-expert/17-architecture-echelle.md) |

## Plan de révision (3 semaines)
1. **S1** : relire cours des niveaux 1–2, refaire tous les exercices **sans** les corrigés.
2. **S2** : [quiz](09-quiz.md) chronométrés ; refaire labs 04, 07, 11 (state/import/refactoring).
3. **S3** : examens blancs officiels (HashiCorp propose des questions d'exemple) ; pour la certification pratique, chronométrez-vous sur le [projet final](../05-projet-final/README.md) (déploiement + débogage + refactoring).

## Conseils
- Connaître **à la lettre** : ordre de priorité des variables, symboles du plan, commandes `state`, différence `count`/`for_each`, comportement des backends, `sensitive` vs state.
- Pratiquer au clavier : l'examen pratique sanctionne la vitesse de diagnostic.
