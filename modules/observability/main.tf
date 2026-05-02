# 1. Namespace isolado para a stack de monitoramento
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "observabilidade"
  }
}

# 2. Prometheus: Coleta de métricas da infraestrutura e pods
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600 # Aumentado para 10 minutos para dar tempo de baixar as imagens

  # DESATIVANDO persistência para o servidor de métricas
  set {
    name  = "server.persistentVolume.enabled"
    value = "false"
  }

  # DESATIVANDO persistência para o Alertmanager
  set {
    name  = "alertmanager.persistentVolume.enabled"
    value = "false"
  }

  # DESATIVANDO persistência para o Pushgateway
  set {
    name  = "pushgateway.persistentVolume.enabled"
    value = "false"
  }
}

# 3. Loki: Centralização e indexação de logs
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  # DESATIVANDO persistência
  set {
    name  = "loki.persistence.enabled"
    value = "false"
  }
}

# 4. Grafana: Dashboards e visualização de dados
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  # DESATIVANDO persistência para o Grafana
  set {
    name  = "persistence.enabled"
    value = "false"
  }

  set {
    name  = "adminPassword"
    value = "admin123"
  }

  # Injeção automática das fontes de dados (Prometheus e Loki)
  values = [
    yamlencode({
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-server.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local"
              access    = "proxy"
              isDefault = true
            },
            {
              name      = "Loki"
              type      = "loki"
              url       = "http://loki.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:3100"
              access    = "proxy"
              isDefault = false
            }
          ]
        }
      }
    })
  ]
}