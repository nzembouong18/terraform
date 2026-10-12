# 20 — Terraform sur Google Cloud

## Provider `google`
```hcl
provider "google" {
  project = var.projet_gcp
  region  = var.region
  default_labels = { gere_par = "terraform" }   # équivalent des default_tags AWS
}
```
Un second provider, `google-beta`, expose les fonctionnalités en préversion.

### Authentification
| Méthode | Usage |
|---------|-------|
| `gcloud auth application-default login` | poste de dev |
| **Workload Identity Federation** (GitHub OIDC → compte de service) | CI/CD ✅ |
| Impersonation (`impersonate_service_account`) | accès temporaire à un SA dédié à Terraform |
| Clé JSON de compte de service | à éviter |

## Particularités GCP
- **Projet = frontière** (facturation, IAM, quotas) ; les APIs doivent être **activées** (`google_project_service`, `disable_on_destroy = false`).
- **VPC global**, sous-réseaux **régionaux** ; `auto_create_subnetworks = false` pour maîtriser l'adressage.
- **IAM** : préférez `google_*_iam_member` (additif) à `iam_binding` (autoritatif sur le rôle) et surtout à `iam_policy` (remplace tout !).
- **Pare-feu** : règles ciblées par `target_tags` ou comptes de service ; SSH via **IAP** (`35.235.240.0/20`) plutôt que `0.0.0.0/0`.
- **Backend `gcs`** : verrouillage natif ; activez le versioning du bucket.
- **Cloud Foundation Fabric / modules `terraform-google-modules`** : modules de référence.

## Comprendre en profondeur

### Modèle de ressources GCP
```
Organisation
 └── Dossier (Folder)
      └── Projet            ← frontière de facturation, de quotas, d'APIs et d'IAM
           └── Ressources   (VPC, bucket, VM…)
```
- Les **projets** sont créés par Terraform (`google_project`) ou fournis ; l'ID du projet est **unique mondialement** et **non réutilisable** après suppression.
- L'IAM s'**hérite** de l'organisation vers le projet : une permission posée trop haut s'applique partout.
- Terraform agit par une **identité** (compte de service) dont les rôles doivent couvrir ce qu'il crée. Utilisez l'**impersonation** pour éviter les clés JSON.

### Activer les APIs : étape oubliée n°1
```hcl
resource "google_project_service" "apis" {
  for_each           = toset(["compute.googleapis.com", "storage.googleapis.com", "iam.googleapis.com"])
  project            = var.projet_gcp
  service            = each.value
  disable_on_destroy = false             # évite de couper l'API pour d'autres usages
}
resource "google_compute_network" "vpc" {
  name                    = "vpc-formation"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]   # dépendance « invisible » classique
}
```
Sans l'API activée, l'erreur *« API has not been used in project … before or it is disabled »* apparaît, parfois quelques minutes après l'activation (propagation).

### Réseau : spécificités GCP
- **VPC global** : un seul VPC couvre toutes les régions ; les **sous-réseaux sont régionaux**.
- **Pare-feu au niveau du VPC** : règles par priorité (0–65535, plus petit = prioritaire), cible par `target_tags` ou compte de service ; deux règles implicites : *deny all ingress*, *allow all egress*.
- **Cloud NAT** (via Cloud Router) pour la sortie Internet sans IP publique.
- **Private Google Access** sur le sous-réseau pour joindre les APIs Google depuis des instances sans IP publique.
- **IAP (Identity-Aware Proxy)** pour SSH/RDP : autoriser `35.235.240.0/20` et utiliser `gcloud compute ssh --tunnel-through-iap`.

### IAM : les trois niveaux d'autorité (à connaître absolument)
| Ressource Terraform | Portée | Risque |
|---------------------|--------|--------|
| `google_*_iam_member` | **ajoute** un membre à un rôle | faible : additif |
| `google_*_iam_binding` | gère **tous** les membres d'un rôle | retire les membres non listés |
| `google_*_iam_policy` | gère **toute** la politique de la ressource | peut vous **verrouiller dehors** |
| `google_*_iam_audit_config` | journalisation d'audit | à manier avec soin |

Règle : `iam_member` par défaut ; `iam_binding` seulement si Terraform est la **seule** source de vérité du rôle ; `iam_policy` quasiment jamais.

### Comptes de service et identités
- Un compte de service par application/rôle (moindre privilège) ; **jamais** le compte de service Compute par défaut.
- Rôles *prédéfinis* ou *custom* ; évitez `roles/owner` et `roles/editor`.
- **Workload Identity Federation** pour la CI (GitHub, GitLab) et **Workload Identity** pour GKE : aucune clé exportée.
- Si une clé JSON est inévitable : durée de vie courte, rotation, stockage dans Secret Manager.

### Provider `google` vs `google-beta`
Les fonctions en préversion exigent `google-beta` pour la ressource concernée (`provider = google-beta`). Mélanger les deux sur un même objet peut provoquer des diffs ; centralisez l'usage dans un module et notez ce qui dépend du beta.

### Backend `gcs`
```hcl
terraform {
  backend "gcs" {
    bucket = "acme-tfstate"
    prefix = "reseau"
  }
}
```
Bucket : versioning, accès uniforme (*uniform bucket-level access*), chiffrement CMEK si requis, règle de cycle de vie pour limiter les anciennes versions, IAM minimal. Le verrouillage est natif.

### Labels et coûts
`default_labels` (provider) + `labels` sur les ressources ; l'export de facturation vers BigQuery permet un suivi par label. Détruire les ressources facturées à l'heure (Cloud NAT, VPN, instances, GKE) à la fin des travaux pratiques ; définir un **budget** avec alerte.

### Modules de référence
`terraform-google-modules` (réseau, IAM, projet, GKE) et **Cloud Foundation Fabric** (Google) offrent des modules robustes et modulaires ; étudiez-les avant d'écrire les vôtres.

## Exercices
1. `terraform init -backend=false && terraform test` (provider simulé).
2. Ajoutez un 3ᵉ sous-réseau `batch` dans `var.sous_reseaux` : combien de ressources changent ?
3. Expliquez la différence entre `google_storage_bucket_iam_member`, `_binding` et `_policy`. Quel risque présente chacun ?
4. Ajoutez une règle de pare-feu `deny` de priorité basse pour tout autre trafic entrant.
5. Ajoutez une **Cloud NAT** (`google_compute_router` + `google_compute_router_nat`) pour la sortie Internet sans IP publique.
6. Défi (compte GCP) : une VM `google_compute_instance` sans IP publique, accessible par `gcloud compute ssh --tunnel-through-iap`, avec le compte de service `sa-app-formation`.
7. Défi : migrez le state vers un backend `gcs`.

## Corrigé
[`solution/`](solution/) — `main.tf` + `tests/gcp.tftest.hcl`.
