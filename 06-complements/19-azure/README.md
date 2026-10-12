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

## Comprendre en profondeur

### Le modèle de ressources Azure vu par Terraform
```
Tenant (Microsoft Entra ID)
 └── Management Group
      └── Subscription          ← frontière de facturation, de quotas et d'IAM
           └── Resource Group   ← conteneur logique ET cycle de vie commun
                └── Ressources  (VNet, Storage, VM…)
```
- Le **Resource Group** est obligatoire pour presque tout et porte l'emplacement (`location`) par défaut ; supprimer le groupe supprime son contenu : à protéger avec un **verrou de gestion** (`azurerm_management_lock`) en production.
- Terraform identifie les objets par leur **ID Azure** (`/subscriptions/…/resourceGroups/…/providers/…`), qui sert aussi d'identifiant d'`import`.
- Les ressources ont un cycle de déploiement propre à Azure Resource Manager (ARM) ; Terraform appelle directement ses API, sans passer par des templates ARM/Bicep.

### `azurerm`, `azapi`, `azuread` : quel provider pour quoi ?
| Provider | Couvre | Remarque |
|----------|--------|----------|
| `azurerm` | la grande majorité des ressources Azure | stable, très documenté |
| `azapi` | **toute** API ARM, y compris préversions | `azapi_resource` avec un `body` JSON ; utile quand `azurerm` est en retard |
| `azuread` | utilisateurs, groupes, applications, principaux de service (Entra ID) | permissions Graph requises |
| `azurerm` + `features {}` | options globales (suppression de RG non vide, soft-delete Key Vault…) | à régler consciemment |

### Réseau : les notions à maîtriser
- **VNet** + **sous-réseaux** (plage CIDR, délégations de service) ; les adresses sont réservées par Azure (5 par sous-réseau).
- **NSG** (Network Security Group) : règles à priorité numérique (plus petit = plus prioritaire, 100–4096) ; associer au sous-réseau (`azurerm_subnet_network_security_group_association`) plutôt qu'à chaque NIC.
- **Peering** de VNets : à déclarer **dans les deux sens**.
- **Private Endpoint** + zone DNS privée pour accéder à un PaaS (Storage, SQL) sans exposition publique.
- Sortie Internet : **NAT Gateway** ou pare-feu ; ne comptez pas sur l'IP publique d'une VM.

### Stockage : durcissement du compte
```hcl
resource "azurerm_storage_account" "s" {
  name                            = "st${var.projet}${random_string.sfx.result}"   # 3-24 car., minuscules+chiffres, unique mondial
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"            # LRS < ZRS < GRS < GZRS (résilience croissante)
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false            # forcer Entra ID (RBAC) plutôt que les clés
  blob_properties { versioning_enabled = true }
}
```
Les clés d'accès partagées sont l'équivalent d'un mot de passe root : préférez **RBAC** (`Storage Blob Data Contributor`) et des identités managées.

### Identité et RBAC
- **Identité managée** (system-assigned ou user-assigned) pour les applications : aucun secret à gérer.
- `azurerm_role_assignment` : `scope` (le plus étroit possible), `role_definition_name`, `principal_id`. Attention : l'attribution de rôles exige que **l'identité de Terraform** ait elle-même `User Access Administrator` ou `Owner` sur la portée ; sinon l'`apply` échoue en 403.
- **Azure Policy** : gouvernance continue côté Azure, complémentaire du policy-as-code sur le plan.
- Secrets applicatifs : **Key Vault** (`azurerm_key_vault`, RBAC activé), jamais en clair dans les variables.

### Particularités qui surprennent
| Sujet | Comportement |
|-------|--------------|
| Suppression d'un Key Vault | *soft delete* : le nom reste réservé ; purge ou récupération nécessaire |
| Noms de ressources | règles différentes par type (longueur, caractères, unicité) |
| Quotas / SKU | disponibilité par région et par subscription : vérifier avant d'apply |
| Ressources `azurerm_virtual_machine` | **dépréciées** → `azurerm_linux_virtual_machine` / `azurerm_windows_virtual_machine` |
| Opérations longues | timeouts configurables (`timeouts { create = "60m" }`) |
| Dépendance des sous-réseaux | un sous-réseau lié à une NIC ne peut pas être détruit avant elle (ordre géré par le graphe) |

### Backend `azurerm` et authentification de la CI
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateacme"
    container_name       = "tfstate"
    key                  = "reseau.tfstate"
    use_oidc             = true               # CI : Workload Identity Federation
    use_azuread_auth     = true               # RBAC sur le blob, pas de clé de compte
  }
}
```
Le compte de stockage du state : **versioning** et *soft delete* des blobs activés, réseau restreint, accès RBAC minimal (`Storage Blob Data Contributor` sur le conteneur).

### Coûts et bonnes pratiques
- Étiquetez via `tags` + `locals` (Azure n'a pas de `default_tags` natif dans `azurerm`).
- Utilisez des **SKU modestes** et **détruisez** les labos : VPN Gateway, Firewall, Bastion et NAT Gateway sont facturés à l'heure.
- Activez les **budgets** et alertes (`azurerm_consumption_budget_subscription`).
- Pour une adoption à grande échelle : **Azure Verified Modules** (AVM) plutôt que des modules écrits maison.

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
