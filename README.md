# 🎓 Formation Terraform — de débutant à expert

Parcours complet, pratique et **vérifié** (chaque lab est exécuté en CI) pour acquérir un **profil Terraform équilibré** : fondamentaux, conception modulaire, exploitation en équipe, sécurité, tests, CI/CD, gouvernance et architecture à l'échelle.

> Langue : français · Terraform ≥ 1.7 (1.9 conseillé) · OpenTofu compatible pour la majorité des labs.

## 🚀 Démarrer
```bash
git clone <ce dépôt> && cd terraform
cd 01-debutant/01-premiers-pas/solution
terraform init && terraform apply
```
Installation détaillée : [docs/00-installation.md](docs/00-installation.md). Les niveaux 1 à 3 ne nécessitent **aucun compte cloud**.

## 🗺️ Parcours

| Niveau | Dossier | Modules | Compte cloud ? |
|--------|---------|---------|:--:|
| 🟢 **1 Débutant** | [`01-debutant`](01-debutant/README.md) | 01 Premiers pas · 02 Variables/outputs · 03 Ressources/data/lifecycle · 04 State | non |
| 🟡 **2 Intermédiaire** | [`02-intermediaire`](02-intermediaire/README.md) | 05 Boucles · 06 Modules · 07 Backends/remote state · 08 Environnements · 09 Fonctions/templates | non |
| 🟠 **3 Avancé** | [`03-avance`](03-avance/README.md) | 10 Tests · 11 Refactoring/import · 12 CI/CD · 13 Sécurité | non (12 : GitHub) |
| 🔴 **4 Expert** | [`04-expert`](04-expert/README.md) | 14 Multi-région · 15 Module « production » · 16 Policy as code · 17 Architecture/échelle · 18 Écrire un provider | optionnel |
| 🏁 **Projet** | [`05-projet-final`](05-projet-final/README.md) | Plateforme web AWS dev/prod | oui (ou `validate`/tests mockés) |

Chaque module = **cours + exercices + `solution/` exécutable**. Planning et grille d'auto-évaluation : [docs/01-parcours-et-evaluation.md](docs/01-parcours-et-evaluation.md).

## 📚 Documentation transverse
| Doc | Contenu |
|-----|---------|
| [00 Installation](docs/00-installation.md) | Terraform, outils, compte cloud, variables d'env |
| [01 Parcours & évaluation](docs/01-parcours-et-evaluation.md) | planning, méthode, matrice de compétences |
| [02 Aide-mémoire](docs/02-cheatsheet.md) | CLI, blocs, symboles, versions marquantes |
| [03 Bonnes pratiques](docs/03-bonnes-pratiques.md) | code, versions, état, processus, anti-patterns |
| [04 Dépannage](docs/04-troubleshooting.md) | erreurs fréquentes + méthode de diagnostic |
| [05 Sécurité](docs/05-securite-et-conformite.md) | checklist avant merge |
| [06 Certification](docs/06-certification.md) | mapping Terraform Associate / Professional |
| [07 Écosystème](docs/07-ecosysteme.md) | licence, OpenTofu, outils, alternatives |
| [08 Glossaire](docs/08-glossaire.md) | vocabulaire |
| [09 Quiz](docs/09-quiz.md) | 40 questions corrigées |

## ✅ Vérifier que tout fonctionne
```bash
./scripts/validate-all.sh --fast   # fmt + validate de tous les labs
./scripts/validate-all.sh          # + apply/idempotence/destroy hors-ligne, terraform test, OPA
```
La CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) exécute ce script à chaque push.

## 🧭 Conseils d'apprentissage
1. **Faites** les exercices avant de lire les corrigés. 2. **Lisez chaque plan** et prédisez-le avant de l'exécuter. 3. **Cassez** des choses sur des labs jetables. 4. **Détruisez** toujours les ressources cloud. 5. Revenez sur le [quiz](docs/09-quiz.md) après chaque niveau.

## 🧱 Structure du dépôt
```
.
├── 01-debutant/ … 04-expert/   # cours + labs (README.md + solution/)
├── 05-projet-final/            # capstone AWS (modules + envs)
├── docs/                       # documentation transverse
├── scripts/validate-all.sh     # validation de tous les labs
└── .github/workflows/ci.yml    # CI du dépôt
```

## 🤝 Contribuer
Ajoutez un lab : dossier `NN-sujet/` avec `README.md` (cours, exercices) + `solution/` ; ajoutez-le dans `scripts/validate-all.sh`. Exécutez `terraform fmt -recursive` avant de pousser.
