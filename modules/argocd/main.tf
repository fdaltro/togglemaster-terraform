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

  # CORREÇÃO: Argumentos devem estar em linhas separadas
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.extraArgs"
    value = "{--insecure}" # [cite: 2]
  }
}

# 3. CRIAÇÃO DINÂMICA DAS APLICAÇÕES
# Criamos uma aplicação no ArgoCD para cada pasta de serviço que você organizou
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
