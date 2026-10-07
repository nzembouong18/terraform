# 06 — Modules

Un **module** = un dossier de `.tf`. Le dossier où vous lancez `terraform` est le **module racine** ; il appelle des **modules enfants**.

## Structure recommandée
```
modules/mon-module/
├── main.tf        # ressources
├── variables.tf   # entrées (avec description + type + validation)
├── outputs.tf     # sorties
├── versions.tf    # required_version + required_providers (bornes, sans config)
└── README.md      # usage (terraform-docs peut le générer)
```

## Appeler un module
```hcl
module "web" {
  source  = "./modules/fichier-config"   # local
  # source  = "terraform-aws-modules/vpc/aws"   + version = "~> 5.0"   # registry
  # source  = "git::https://github.com/org/repo.git//sous/dossier?ref=v1.2.0"   # git, TOUJOURS épinglé
  nom = "web"
}
# lecture d'une sortie : module.web.chemin
```
`count`/`for_each` fonctionnent aussi sur les modules (≥ 0.13).

## Principes de conception
1. **Une responsabilité** par module (réseau, base de données…), pas un « module fourre-tout ».
2. **Peu de variables obligatoires**, valeurs par défaut *sûres*.
3. **Pas de `provider` configuré dans un module** : seul le racine configure ; le module déclare ce dont il a besoin.
4. **Outputs** pour tout ce dont un consommateur pourrait avoir besoin (id, arn).
5. **Composition > héritage** : le racine assemble des modules (`reseau` → `application`) en passant les outputs.
6. Versionnez (tags git SemVer) et documentez ; modifier une variable = changement potentiellement cassant.

## Exercices
1. Lisez `solution/modules/fichier-config`. Appelez-le une fois, puis 3 fois avec `for_each`.
2. Ajoutez une variable `proprietaire` avec validation et un output `empreinte`.
3. Listez les adresses créées (`terraform state list`) : repérez le préfixe `module.services["api"]`.
4. Ajoutez un 2e module `module "lecteur"` qui consomme la sortie `chemin` du premier (composition).
5. Défi : extraire une partie de votre code racine vers un module **sans détruire** (`moved` — voir module 11).

## Corrigé
[`solution/`](solution/)
