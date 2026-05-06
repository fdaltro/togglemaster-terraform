# 1. Namespace isolado para a stack de monitorização
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "observabilidade"
  }
}

# 2. Prometheus: Recolha de métricas (Alertmanager desativado no Helm)
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  # Desativa persistência do Servidor Principal para rodar em t3.medium
  set {
    name  = "server.persistentVolume.enabled"
    value = "false"
  }

  # DESATIVAÇÃO DO ALERTMANAGER VIA HELM
  # Evita que o Helm crie um StatefulSet que exige PVC
  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  set {
    name  = "pushgateway.persistentVolume.enabled"
    value = "false"
  }
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
    value = "false"
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
    value = "false"
  }

  set {
    name  = "adminPassword"
    value = "admin123"
  }

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

# ==========================================================
# 5. CONFIGURAÇÃO MANUAL DO ALERTMANAGER (SOLUÇÃO DE CONTORNO)
# ==========================================================

# Cria o ConfigMap que o Helm deixou de criar ao ser desativado
resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "prometheus-alertmanager"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "alertmanager.yml" = yamlencode({
      global = {
        resolve_timeout = "5m"
      }
      route = {
        group_by        = ["alertname"]
        group_wait      = "10s"
        group_interval  = "10s"
        repeat_interval = "1h"
        receiver        = "default-receiver"
      }
      receivers = [
        {
          name = "default-receiver"
        }
      ]
    })
  }
}

# Deployment manual usando emptyDir para garantir status 'Running'
resource "kubernetes_deployment" "alertmanager_manual" {
  # Garante que o ConfigMap existe antes de tentar montar o volume
  depends_on = [kubernetes_config_map.alertmanager_config]

  metadata {
    name      = "alertmanager-manual"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "alertmanager-manual"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "alertmanager-manual"
      }
    }

    template {
      metadata {
        labels = {
          app = "alertmanager-manual"
        }
      }

      spec {
        container {
          name  = "alertmanager"
          image = "quay.io/prometheus/alertmanager:v0.32.1"
          args  = [
            "--config.file=/etc/alertmanager/alertmanager.yml",
            "--storage.path=/alertmanager"
          ]

          port {
            container_port = 9093
            name           = "http"
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/alertmanager"
          }

          volume_mount {
            name       = "storage-volume"
            mount_path = "/alertmanager"
          }
        }

        volume {
          name = "config-volume"
          config_map {
            name = "prometheus-alertmanager"
          }
        }

        # Armazenamento efêmero para evitar erros de PVC
        volume {
          name = "storage-volume"
          empty_dir {}
        }
      }
    }
  }
}

# Serviço para expor o Alertmanager manual
resource "kubernetes_service" "alertmanager_manual_svc" {
  metadata {
    name      = "alertmanager-manual-svc"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    selector = {
      app = "alertmanager-manual"
    }

    port {
      port        = 9093
      target_port = 9093
      name        = "http"
    }

    type = "ClusterIP"
  }
}
