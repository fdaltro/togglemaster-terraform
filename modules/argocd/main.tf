# 1. Namespace e 2. Helm Release permanecem iguais...
resource "kubernetes_namespace" "argocd" {
  metadata { name = "argocd" }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.7.1"

  set { name = "server.service.type", value = "LoadBalancer" }
  set { name = "server.extraArgs", value = "{--insecure}" }
}

# 3. CRIAÇÃO DINÂMICA DAS APLICAÇÕES
# Criamos uma aplicação separada no ArgoCD para cada pasta de serviço
resource "kubernetes_manifest" "togglemaster_apps" {
  for_each = toset(["auth", "flag", "targeting", "evaluation", "analytics"])

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "togglemaster-${each.key}"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/fdaltro/togglemaster-gitops.git"
        targetRevision = "HEAD"
        # APONTAMENTO CORRETO: apps/analytics, apps/auth, etc.
        path           = "apps/${each.key}" 
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "togglemaster"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}