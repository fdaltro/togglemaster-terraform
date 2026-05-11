# ==========================================================
# 1. NAMESPACE
# ==========================================================
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "observabilidade"
  }
}

# ==========================================================
# 2. PROMETHEUS (Otimizado para Receber Dados do Otel)
# ==========================================================
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  set {
    name  = "server.persistentVolume.enabled"
    value = "false"
  }

  set {
    name  = "alertmanager.enabled"
    value = "false" # Desativado para usar o Manual abaixo 
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "pushgateway.persistentVolume.enabled"
    value = "false"
  }

  # Habilita o recebimento de métricas via Remote Write do Otel Collector
  set {
    name  = "server.extraFlags[0]"
    value = "--enable-feature=remote-write-receiver"
  }

  set {
    name  = "server.alertmanagers[0].static_configs[0].targets[0]"
    value = "alertmanager-manual-svc.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9093"
  }
}

# ==========================================================
# 3. LOKI (Sem persistência de disco)
# ==========================================================
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600 [cite: 3]

  set {
    name  = "loki.persistence.enabled"
    value = "false"
  }
}

# ==========================================================
# 4. GRAFANA (Com LoadBalancer e DataSources Injetados)
# ==========================================================
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "persistence.enabled"
    value = "false"
  }

  set {
    name  = "adminPassword"
    value = "admin123" [cite: 4]
  }

  values = [
    yamlencode({
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus" [cite: 5]
              url       = "http://prometheus-server.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local"
              access    = "proxy"
              isDefault = true
            },
            {
              name      = "Loki" [cite: 6]
              type      = "loki"
              url       = "http://loki.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:3100"
              access    = "proxy"
            },
            {
              name      = "Jaeger" [cite: 7]
              type      = "jaeger"
              url       = "http://jaeger-query.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:16686"
              access    = "proxy"
            }
          ]
        }
      }
    })
  ]
}

# ==========================================================
# 5. ALERTMANAGER MANUAL (Solução para Evitar Erros de PVC)
# ==========================================================
resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "prometheus-alertmanager"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "alertmanager.yml" = yamlencode({
      global = { resolve_timeout = "5m" }
      route = {
        group_by        = ["alertname"] [cite: 9]
        group_wait      = "10s"
        group_interval  = "10s"
        repeat_interval = "1h"
        receiver        = "default-receiver"
      }
      receivers = [{ name = "default-receiver" }]
    })
  }
}

resource "kubernetes_deployment" "alertmanager_manual" {
  depends_on = [kubernetes_config_map.alertmanager_config] [cite: 11]

  metadata {
    name      = "alertmanager-manual"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels    = { app = "alertmanager-manual" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "alertmanager-manual" } }
    template {
      metadata { labels = { app = "alertmanager-manual" } }
      spec {
        container {
          name  = "alertmanager"
          image = "quay.io/prometheus/alertmanager:v0.32.1"
          args  = ["--config.file=/etc/alertmanager/alertmanager.yml", "--storage.path=/alertmanager"] [cite: 12]
          port { container_port = 9093; name = "http" }
          volume_mount { name = "config-volume"; mount_path = "/etc/alertmanager" }
          volume_mount { name = "storage-volume"; mount_path = "/alertmanager" } [cite: 14]
        }
        volume { name = "config-volume"; config_map { name = "prometheus-alertmanager" } }
        volume { name = "storage-volume"; empty_dir {} } [cite: 15]
      }
    }
  }
}

resource "kubernetes_service" "alertmanager_manual_svc" {
  metadata {
    name      = "alertmanager-manual-svc"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  spec {
    selector = { app = "alertmanager-manual" }
    port { port = 9093; target_port = 9093; name = "http" } [cite: 16]
    type = "ClusterIP"
  }
}

# ==========================================================
# 6. JAEGER (Backend de Traces - Em Memória)
# ==========================================================
resource "helm_release" "jaeger" {
  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  set {
    name  = "allInOne.enabled"
    value = "true" 
  }

  set {
    name  = "storage.type"
    value = "memory"
  }
}

# ==========================================================
# 7. OPENTELEMETRY COLLECTOR (Com Nome Fixo e Pipelines)
# ==========================================================
resource "helm_release" "otel_collector" {
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600 [cite: 18]
  depends_on = [helm_release.prometheus, helm_release.loki, helm_release.jaeger]

  # RESOLVE O ERRO DE DNS: Força o nome para 'otel-collector'
  set {
    name  = "fullnameOverride"
    value = "otel-collector"
  }

  set {
    name  = "image.repository"
    value = "otel/opentelemetry-collector-contrib"
  }

  set {
    name  = "image.tag"
    value = "0.104.0"
  }

  values = [
    yamlencode({
      mode = "deployment"
      config = {
        receivers = {
          otlp = {
            protocols = {
              grpc = { endpoint = "0.0.0.0:4317" }
              http = { endpoint = "0.0.0.0:4318" } [cite: 20]
            }
          }
        }
        processors = {
          batch = { send_batch_size = 1000; timeout = "10s" }
          memory_limiter = { check_interval = "5s"; limit_mib = 250; spike_limit_mib = 50 } [cite: 21]
        }
        exporters = {
          prometheusremotewrite = {
            endpoint = "http://prometheus-server.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:80/api/v1/write"
            tls = { insecure = true } [cite: 22]
          }
          loki = {
            endpoint = "http://loki.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:3100/loki/api/v1/push"
          }
          "otlp/jaeger" = {
            endpoint = "jaeger-collector.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:4317"
            tls = { insecure = true } [cite: 23]
          }
        }
        service = {
          pipelines = {
            metrics = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"] [cite: 25]
              exporters  = ["prometheusremotewrite"]
            }
            logs = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["loki"] [cite: 26]
            }
            traces = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["otlp/jaeger"] [cite: 27]
            }
          }
        }
      }
    })
  ]
}
