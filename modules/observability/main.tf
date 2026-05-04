# 1. Namespace isolado para a stack de monitoramento
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "observabilidade"
  }
}

# 2. Prometheus: Coleta de métricas e Alertmanager
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  # Desativando persistência para evitar erros de PVC no AWS Academy
  set {
    name  = "server.persistentVolume.enabled"
    value = "true"
  }

  set {
    name  = "alertmanager.persistentVolume.enabled"
    value = "true"
  }

  set {
    name  = "pushgateway.persistentVolume.enabled"
    value = "true"
  }

  # RESOLUÇÃO DO ERRO: Injeção de configuração básica para o Alertmanager não dar Crash
  values = [
    yamlencode({
      alertmanager = {
        config = {
          global = {
            resolve_timeout = "5m"
          }
          route = {
            group_by = ["alertname"]
            group_wait = "10s"
            group_interval = "10s"
            repeat_interval = "1h"
            receiver = "default-receiver"
          }
          receivers = [
            {
              name = "default-receiver"
            }
          ]
        }
      }
    })
  ]
}

# 3. Loki: Agregador de Logs
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
}

# 4. Grafana: Dashboards e Visualização
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
            }
          ]
        }
      }
    })
  ]
}
