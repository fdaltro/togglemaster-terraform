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
  timeout    = 600

  # Ativando persistência para o servidor de métricas com LOCAL PATH
  set {
    name  = "server.persistentVolume.enabled"
    value = "true"
  }
  set {
    name  = "server.persistentVolume.storageClass"
    value = "local-path"
  }
  set {
    name  = "server.persistentVolume.size"
    value = "8Gi"
  }

  # Ativando persistência para o Alertmanager com LOCAL PATH
  set {
    name  = "alertmanager.persistentVolume.enabled"
    value = "true"
  }
  set {
    name  = "alertmanager.persistentVolume.storageClass"
    value = "local-path"
  }

  # Ativando persistência para o Pushgateway com LOCAL PATH
  set {
    name  = "pushgateway.persistentVolume.enabled"
    value = "true"
  }
  set {
    name  = "pushgateway.persistentVolume.storageClass"
    value = "local-path"
  }
}

# 3. Loki: Centralização e indexação de logs
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  set {
    name  = "loki.persistence.enabled"
    value = "true"
  }
  set {
    name  = "loki.persistence.storageClass"
    value = "local-path"
  }
  set {
    name  = "loki.persistence.size"
    value = "5Gi"
  }
}

# 4. Grafana: Dashboards e visualização de dados
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.storageClass"
    value = "local-path"
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