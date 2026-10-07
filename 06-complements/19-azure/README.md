# 19 — Terraform sur Azure

## Provider `azurerm`
```hcl
provider "azurerm" {
  features {}                         # bloc obligatoire (même vide)
  subscription_id = var.subscription_id   # obligatoire depuis azurerm 4.x (ou ARM_SUBSCRIPTION_ID)
}
```

### Authentification (du plus simple au plus sûr)
| Méthode | Usage |
|---------|-------|
| `az login` (Azure CLI) | poste de dev |
| Service principal + secret (`ARM_CLIENT_ID/SECRET/TENANT_ID`) | à éviter (secret longue durée) |
| **OIDC / Workload Identity Federation** (`use_oidc = true`) | CI/CD (GitHub Actions) ✅ |
| Managed Identity (`use_msi = true`) | exécution depuis une VM/runner Azure |

## Particularités Azure à connaître
- **Tout vit dans un Resource Group** : `azurerm_resource_group` en premier ; sa suppression détruit tout son contenu.
- **Noms contraints** : un compte de stockage = 3-24 caractères, minuscules/chiffres, **unique mondialement** → suffixe `random_string`.
- **Régions** : `francecentral`, `westeurope`… vérifiez la disponibilité des SKU (`az vm list-skus`).
- **RBAC** : `azurerm_role_assignment` (moindre privilège, portée la plus étroite).
- **Backend** : `azurerm` (compte de stockage + conteneur ; verrouillage natif par *lease* du blob ; `use_oidc`/`use_azuread_auth`).
- **`azapi`** : provider complémentaire pour les ressources/propriétés pas encore couvertes par `azurerm`.
- **Azure Verified Modules (AVM)** : modules officiels Microsoft pour Terraform (registry).

## Ce que fait la solution
VNet + sous-réseaux (`for_each`) + NSG avec règles générées par `dynamic` (HTTP/HTTPS seulement sur `web`) + compte de stockage durci (TLS 1.2, pas d'accès public, versioning, ZRS).

## Exercices
1. `terraform init -backend=false && terraform test` : lisez le test (provider **simulé**, aucun compte). Pourquoi doit-on fournir des `id` réalistes dans `mock_resource` ?
2. Ajoutez un sous-réseau `admin` avec `ouvrir_http = false` : que montre le plan/test ?
3. Ajoutez un `azurerm_role_assignment` donnant `Storage Blob Data Reader` à une identité (variable `object_id`).
4. Remplacez le suffixe aléatoire par une valeur déterministe (hash du `subscription_id`) : avantages/inconvénients ?
5. Activez le backend `azurerm` (bloc commenté) et migrez : `terraform init -migrate-state`.
6. Défi (compte Azure) : ajoutez une VM Linux dans `snet-web` (clé SSH, **sans** mot de passe), `apply`, puis `destroy`.
7. Défi sécurité : `checkov -d .` → corrigez ou justifiez chaque finding.

## Corrigé
[`solution/`](solution/) — `main.tf` + `tests/azure.tftest.hcl`.
