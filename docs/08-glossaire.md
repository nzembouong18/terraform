# Glossaire

| Terme | Définition |
|-------|-----------|
| **Backend** | Où est stocké le state (et comment il est verrouillé) |
| **Blast radius** | Périmètre d'impact potentiel d'une erreur |
| **Data source** | Lecture d'un objet existant |
| **Drift (dérive)** | Écart entre l'infrastructure réelle et le state/code |
| **HCL** | HashiCorp Configuration Language |
| **HCP Terraform** | Service SaaS de HashiCorp (state, runs, policies) — anciennement Terraform Cloud |
| **Idempotence** | Appliquer plusieurs fois donne le même résultat |
| **Lock file** | `.terraform.lock.hcl`, versions/hash des providers |
| **Module** | Ensemble de fichiers `.tf` réutilisable |
| **Plan** | Liste d'actions calculée par comparaison code / state / réalité |
| **Provider** | Plugin qui traduit les ressources en appels API |
| **Registry** | Catalogue de providers et modules |
| **Remote state** | State stocké à distance ; `terraform_remote_state` lit les outputs d'un autre |
| **Resource address** | Chemin unique d'une instance (`module.m.aws_x.n["k"]`) |
| **State** | Correspondance code ↔ ressources réelles |
| **Workspace** | Instance d'état distincte pour une même config (CLI) ; ou unité de gestion (HCP) |
| **Ephemeral** | Valeur non persistée dans le state/plan (≥ 1.10) |
| **Write-only** | Argument jamais stocké dans le state (≥ 1.11) |
