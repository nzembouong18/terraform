terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

variable "kubeconfig" {
  type        = string
  description = "Chemin du kubeconfig (cluster kind/minikube/EKS/AKS/GKE)"
  default     = "~/.kube/config"
}

variable "contexte" {
  type    = string
  default = "kind-formation"
}

variable "replicas" {
  type    = number
  default = 2
}

variable "image" {
  type    = string
  default = "nginx:1.27-alpine"
}

provider "kubernetes" {
  config_path    = var.kubeconfig
  config_context = var.contexte
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig
    config_context = var.contexte
  }
}

locals {
  labels = {
    "app.kubernetes.io/name"       = "demo"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_namespace" "demo" {
  metadata {
    name   = "demo"
    labels = local.labels
  }
}

resource "kubernetes_config_map" "page" {
  metadata {
    name      = "page-accueil"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  data = {
    "index.html" = "<h1>Bonjour depuis Terraform</h1>"
  }
}

resource "kubernetes_deployment" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = "nginx"
          image = var.image

          port {
            container_port = 80
          }

          resources {
            requests = { cpu = "50m", memory = "32Mi" }
            limits   = { cpu = "200m", memory = "128Mi" }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false # nginx écrit dans /var/cache ; voir README pour durcir
          }

          volume_mount {
            name       = "page"
            mount_path = "/usr/share/nginx/html"
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
          }
        }

        volume {
          name = "page"
          config_map {
            name = kubernetes_config_map.page.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  spec {
    selector = local.labels
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

# Helm : installer un chart packagé (ici le chart « metrics-server »)
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls}" # kind uniquement !
  }
}

output "service" {
  value = "${kubernetes_service.web.metadata[0].name}.${kubernetes_namespace.demo.metadata[0].name}.svc"
}
