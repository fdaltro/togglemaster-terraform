resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.7.1" # Versão estável do Chart

  # Configuração para expor o servidor via LoadBalancer (facilita o acesso na Academy)
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  # Desabilita o HTTPS para evitar problemas de certificado auto-assinado no teste inicial
  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
}