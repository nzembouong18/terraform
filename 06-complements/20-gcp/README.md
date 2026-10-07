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
