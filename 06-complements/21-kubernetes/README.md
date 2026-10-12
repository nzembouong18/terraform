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

## Comprendre en profondeur

### Pourquoi la frontière Terraform / Kubernetes est délicate
Terraform stocke un **état** et applique des changements à la demande ; Kubernetes est un système de **contrôleurs** qui réconcilient en continu. Quand les deux modifient le même objet (par exemple `replicas` géré par un HPA et par Terraform), ils se battent. Décidez pour chaque objet **qui en est propriétaire** :

| Objet | Propriétaire conseillé |
|-------|-----------------------|
| Cluster, nœuds, réseau, IAM | **Terraform** |
| Namespaces, quotas, RBAC de base, NetworkPolicies par défaut | **Terraform** (socle de plateforme) |
| Charts d'infrastructure (ingress-controller, cert-manager, Argo CD) | **Terraform** (`helm_release`) à l'installation initiale |
| Applications métier | **GitOps** (Argo CD / Flux) |
| Objets modifiés dynamiquement (HPA→replicas, jobs) | Kubernetes — `ignore_changes` côté Terraform |

### Configurer les providers sur un cluster cloud
```hcl
data "aws_eks_cluster" "c"      { name = var.cluster }
data "aws_eks_cluster_auth" "c" { name = var.cluster }       # jeton court (15 min)

provider "kubernetes" {
  host                   = data.aws_eks_cluster.c.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.c.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.c.token
}
# alternative plus robuste : exec { api_version = "client.authentication.k8s.io/v1beta1"  command = "aws"  args = ["eks","get-token","--cluster-name",var.cluster] }
```
Le jeton est de courte durée : pour de longs `apply`, le bloc `exec` (jeton re-demandé) est plus sûr.

### Les trois façons de décrire un objet Kubernetes
| Méthode | Avantages | Inconvénients |
|---------|-----------|---------------|
| Ressources typées `kubernetes_deployment_v1`… | validation fine, auto-complétion, plan lisible | verbeux, retard sur les nouvelles API |
| `kubernetes_manifest` (YAML/HCL générique) | tout objet, CRD inclus | cluster joignable **dès le plan**, schéma chargé à l'exécution |
| `helm_release` | écosystème de charts | valeurs de chart peu typées, diff opaque |

Astuce : lisez un YAML existant avec `yamldecode(file("x.yaml"))` et passez-le à `kubernetes_manifest`; pour plusieurs documents, utilisez `provider::kubernetes::manifest_decode_multi` (≥ 1.8) ou `data "kubectl_file_documents"`.

### Helm via Terraform
```hcl
resource "helm_release" "ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.2"              # TOUJOURS épingler
  namespace        = "ingress"
  create_namespace = true
  values           = [yamlencode({ controller = { replicaCount = 2, service = { type = "LoadBalancer" } } })]
  atomic           = true                   # rollback automatique si le déploiement échoue
  timeout          = 600
}
```
Points d'attention : `atomic`/`wait` pour détecter les échecs ; `values` en `yamlencode` plutôt qu'en heredoc ; `terraform destroy` désinstalle la release ; les **CRDs** posées par un chart ne sont pas toujours supprimées. Les `set { sensitive = true }` masquent les secrets du plan mais pas du state.

### Ordre d'installation : le piège des CRDs
Un `kubernetes_manifest` d'une ressource personnalisée échoue si sa CRD n'est pas encore installée (même avec `depends_on`, car le plan s'exécute avant). Solutions : installer la CRD/le chart dans un **état précédent**, utiliser des ressources typées, ou le provider `kubectl` (`kubectl_manifest`), qui ne valide pas le schéma au plan.

### Redémarrer un pod quand sa configuration change
Kubernetes ne redémarre pas un Deployment quand un ConfigMap change. Astuce : poser une annotation dérivée du contenu.
```hcl
template {
  metadata {
    annotations = { "checksum/config" = sha256(jsonencode(kubernetes_config_map_v1.app.data)) }
  }
}
```

### Sécurité du socle
- **Moindre privilège** : `kubernetes_role_v1` + `kubernetes_role_binding_v1` par namespace plutôt que `cluster-admin`.
- **Quotas et limites** : `kubernetes_resource_quota_v1`, `kubernetes_limit_range_v1`.
- **NetworkPolicy** « deny all » par défaut, puis ouvertures explicites.
- **Pod Security Standards** : labels `pod-security.kubernetes.io/enforce: restricted` sur les namespaces.
- **Secrets** : éviter `kubernetes_secret` avec une valeur en clair (elle est dans le state) → External Secrets Operator, Secrets Store CSI, Sealed Secrets.

### Cycle de vie et destruction
Supprimer un namespace supprime tout son contenu ; des *finalizers* peuvent bloquer la suppression. Détruire le cluster **avant** les ressources Kubernetes laisse celles-ci dans l'état sans moyen de les supprimer : détruisez dans l'ordre inverse de la création (couche plateforme, puis cluster).

### Alternatives et compléments
| Outil | Rôle |
|-------|------|
| Argo CD / Flux | synchronisation continue Git → cluster (GitOps) |
| Crossplane | gérer l'infra cloud **depuis** Kubernetes (CRD) |
| Kustomize / Helm seuls | déploiement d'applications sans état Terraform |
| Cluster API | cycle de vie de clusters déclaratif |

Voir aussi le dépôt de formation Kubernetes (modules « Helm/Kustomize » et « Production & GitOps ») pour la couche applicative.

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
