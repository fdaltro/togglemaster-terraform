# ==========================================================
# 1. NAMESPACE
# ==========================================================
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "observabilidade"
  }
}

# ==========================================================
# 2. PROMETHEUS
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
    value = "false"
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "pushgateway.persistentVolume.enabled"
    value = "false"
  }

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
# 3. LOKI
# ==========================================================
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

# ==========================================================
# 4. GRAFANA
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
            },
            {
              name      = "Jaeger"
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
# 5. ALERTMANAGER MANUAL
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
        group_by        = ["alertname"]
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
  depends_on = [kubernetes_config_map.alertmanager_config]

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
          args  = ["--config.file=/etc/alertmanager/alertmanager.yml", "--storage.path=/alertmanager"]
          
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
        volume { 
          name = "storage-volume"
          empty_dir {} 
        }
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
    port { 
      port        = 9093
      target_port = 9093
      name        = "http" 
    }
    type = "ClusterIP"
  }
}

# ==========================================================
# 6. JAEGER
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
# 7. OPENTELEMETRY COLLECTOR
# ==========================================================
resource "helm_release" "otel_collector" {
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600
  depends_on = [helm_release.prometheus, helm_release.loki, helm_release.jaeger]

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
              http = { endpoint = "0.0.0.0:4318" }
            }
          }
        }
        processors = {
          batch = { send_batch_size = 1000, timeout = "10s" }
          memory_limiter = { check_interval = "5s", limit_mib = 250, spike_limit_mib = 50 }
        }
        exporters = {
          prometheusremotewrite = {
            endpoint = "http://prometheus-server.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:80/api/v1/write"
            tls = { insecure = true }
          }
          loki = {
            endpoint = "http://loki.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:3100/loki/api/v1/push"
          }
          "otlp/jaeger" = {
            endpoint = "jaeger-collector.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:4317"
            tls = { insecure = true }
          }
        }
        service = {
          pipelines = {
            metrics = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["prometheusremotewrite"]
            }
            logs = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["loki"]
            }
            traces = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["otlp/jaeger"]
            }
          }
        }
      }
    })
  ]
}
