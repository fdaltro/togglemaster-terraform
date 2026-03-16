terraform {
  required_providers {
    # Isso avisa ao módulo que o 'kubectl' vem do gavinbunney, não da hashicorp
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    helm = {
      source  = "hashicorp/helm"
    }
  }
}

# 1. Criação do Namespace para o ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# 2. Instalação do ArgoCD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.7.1"

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
}

# 3. CRIAÇÃO DINÂMICA DAS APLICAÇÕES
# Usamos kubectl_manifest para evitar erros de validação durante o 'plan'
resource "kubectl_manifest" "togglemaster_apps" {
  for_each = toset(["auth", "flag", "targeting", "evaluation", "analytics"])

  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: togglemaster-${each.key}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: "https://github.com/fdaltro/togglemaster-gitops.git"
    targetRevision: HEAD
    path: "apps/${each.key}"
  destination:
    server: "https://kubernetes.default.svc"
    namespace: togglemaster
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
YAML

  depends_on = [helm_release.argocd]
}