# 21 — Kubernetes et Helm avec Terraform

## Deux rôles distincts
| Couche | Outil adapté |
|--------|--------------|
| **Cluster** (EKS/AKS/GKE, nœuds, réseau) | Terraform ✅ |
| **Contenu** (Deployments, Services…) | Terraform pour le socle (namespaces, RBAC, quotas, charts d'infra) ; **GitOps** (Argo CD / Flux) pour les applications |

> ⚠️ **Ne créez pas le cluster et ses ressources Kubernetes dans le même état** : le provider `kubernetes` a besoin d'un cluster *existant* pour se configurer. Séparez en 2 états (couche « cluster » puis « plateforme »).

## Providers
```hcl
provider "kubernetes" { config_path = "~/.kube/config"  config_context = "kind-formation" }
provider "helm" { kubernetes { config_path = "~/.kube/config" } }
```
En cloud : configurez via `host`, `cluster_ca_certificate` et un `exec` (jeton éphémère `aws eks get-token`, `kubelogin`, `gke-gcloud-auth-plugin`) plutôt qu'un jeton statique.

## Ressources
- `kubernetes_*` : une ressource par objet (versions « natives »). `kubernetes_manifest` accepte du YAML arbitraire (CRD) mais exige que le cluster soit joignable **dès le plan**.
- `helm_release` : installe un chart (versionnez toujours `version`) ; `values` ou `set` ; `terraform destroy` désinstalle la release.
- Alternatives : provider `kubectl` (manifests), `kustomization`.

## Lab pas à pas (gratuit, local)
```bash
# 1. Cluster local (Docker requis) : https://kind.sigs.k8s.io
kind create cluster --name formation          # contexte : kind-formation
kubectl get nodes

# 2. Appliquer
cd solution
terraform init
terraform plan
terraform apply

# 3. Vérifier
kubectl -n demo get deploy,svc,pods
kubectl -n demo port-forward svc/web 8080:80 &  curl localhost:8080

# 4. Nettoyer
terraform destroy && kind delete cluster --name formation
```

## Exercices
1. Lisez le plan : quelle ressource est créée en premier, et pourquoi (graphe de dépendances) ?
2. Passez `replicas = 3` et appliquez : modification en place ou remplacement ? Vérifiez avec `kubectl`.
3. Changez le `ConfigMap` : le Deployment se met-il à jour tout seul ? Comment forcer un redémarrage (annotation avec hash du contenu : `sha256(jsonencode(...))`) ?
4. Ajoutez un `kubernetes_resource_quota` et un `kubernetes_network_policy` « deny all » sur le namespace.
5. Remplacez `kubernetes_deployment` par un **module** réutilisable `app-web` (`nom`, `image`, `replicas`, `port`) et déployez 2 applications avec `for_each`.
6. Défi : durcissez le conteneur (`read_only_root_filesystem = true` + `emptyDir` pour `/var/cache/nginx` et `/var/run`, `run_as_non_root`, utilisateur non-root).
7. Défi : séparez en deux états `cluster` (kind via `tehcyx/kind`) → `plateforme` (cette solution) reliés par `terraform_remote_state`.

## Corrigé
[`solution/`](solution/) (validé syntaxiquement en CI ; l'`apply` nécessite un cluster).
