# 01 — Premiers pas

## Cours

### Qu'est-ce que Terraform ?
Terraform décrit une infrastructure **de façon déclarative** (« je veux ça ») dans des fichiers `.tf` (langage **HCL**). Il compare l'état **désiré** (code) à l'état **connu** (state) et à la **réalité** (via les APIs des *providers*), puis calcule le plan d'actions.

```
 code .tf ──► terraform plan ──► diff ──► terraform apply ──► API du provider ──► infra réelle
                    ▲                                              │
                    └──────────────── state (.tfstate) ◄───────────┘
```

### Vocabulaire
| Terme | Définition |
|-------|-----------|
| **Provider** | Plugin qui parle à une API (AWS, Azure, GCP, Kubernetes, local, random…) |
| **Resource** | Un objet géré (`resource "type" "nom" {}`) |
| **Data source** | Un objet *lu* sans être géré (`data "type" "nom" {}`) |
| **State** | Fichier JSON qui mappe votre code aux objets réels |
| **Plan** | Liste des actions (`+` créer, `~` modifier, `-` détruire, `-/+` remplacer) |

### Le workflow
```bash
terraform init       # télécharge providers/modules, initialise le backend
terraform fmt        # formate le code
terraform validate   # vérifie la syntaxe et la cohérence interne
terraform plan       # montre ce qui va changer (ne change rien)
terraform apply      # applique (demande confirmation)
terraform destroy    # détruit tout ce que la config gère
```
Fichiers générés : `.terraform/` (plugins, **ne pas versionner**), `.terraform.lock.hcl` (versions des providers, **à versionner** dans un vrai projet), `terraform.tfstate` (**jamais dans git**).

### Anatomie d'un fichier
```hcl
terraform {                        # réglages globaux : version, providers requis
  required_version = ">= 1.6.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}
resource "random_pet" "serveur" {  # type + nom local
  length = 2                       # arguments
}
# référence : <type>.<nom>.<attribut>
output "nom" { value = random_pet.serveur.id }
```
Contraintes de version : `= 1.2.3`, `>= 1.2`, `~> 1.2` (≥ 1.2 et < 2.0), `~> 1.2.3` (≥ 1.2.3 et < 1.3).

## Exercices

1. **Hello Terraform** — dans `exercice/main.tf`, déclarez `random_pet` et un `local_file` dont le contenu contient le nom généré. Lancez `init`, `plan`, `apply`. Ouvrez `out/bienvenue.txt`.
2. **Lire le plan** — relancez `plan` : que dit-il ? (*No changes*). Puis changez `length = 3` : quels symboles voyez-vous ? Pourquoi `-/+` (*forces replacement*) ?
3. **Dérive (drift)** — modifiez à la main `out/bienvenue.txt`, relancez `plan`. Que fait Terraform ? Appliquez.
4. **Exploration** — `terraform show`, `terraform output`, `terraform state list`, `terraform graph | dot -Tpng > g.png` (si Graphviz).
5. **Nettoyage** — `terraform destroy`. Le fichier a-t-il disparu ?

## Questions de compréhension
- Pourquoi `random_pet` ne change-t-il pas à chaque `apply` ?
- Quelle différence entre `plan` et `apply` ? Que se passe-t-il si on supprime le state ?
- À quoi sert `.terraform.lock.hcl` ?

<details><summary>Réponses</summary>

- La valeur est stockée dans le **state** ; elle ne change que si un argument « force replacement » change.
- `plan` calcule seulement ; `apply` exécute. Sans state, Terraform ne connaît plus ses ressources et voudra tout recréer (doublons dans le cloud !).
- Il fige les versions exactes (et hash) des providers pour des builds reproductibles.
</details>

## Corrigé
[`solution/main.tf`](solution/main.tf) — `cd solution && terraform init && terraform apply`.
