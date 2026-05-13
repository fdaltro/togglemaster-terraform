# ==========================================================
# 1. NAMESPACE
# ==========================================================
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "observabilidade"
  }
}

# ==========================================================
# 2. PROMETHEUS (Sem Alertmanager nativo e sem discos)
# ==========================================================
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  set {
    name  = "server.extraFlags[0]"
    value = "web.enable-remote-write-receiver"
  }

  set {
    name  = "server.extraFlags[1]"
    value = "enable-feature=remote-write-receiver"
  }

  # Permite que o container configmap-reload envie o comando de restart para o Prometheus
  set {
    name  = "server.extraFlags[2]"
    value = "web.enable-lifecycle"
  }

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
    name  = "server.alertmanagers[0].static_configs[0].targets[0]"
    value = "alertmanager-manual-svc.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9093"
  }
}

# ==========================================================
# 3. LOKI (Sem discos)
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
# 4. GRAFANA (Sem discos e com Fontes Injetadas)
# ==========================================================
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
            },
            {
              name      = "Jaeger"
              type      = "jaeger"
              url       = "http://jaeger.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:16686"
              access    = "proxy"
            }
          ]
        }
      }
    })
  ]
}

# ==========================================================
# 5. ALERTMANAGER MANUAL (Solução de Contorno)
# ==========================================================
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

resource "kubernetes_deployment" "alertmanager_manual" {
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
# 7. OPENTELEMETRY COLLECTOR (O Roteador Central)
# ==========================================================
resource "helm_release" "otel_collector" {
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  
  set {
    name  = "image.repository"
    value = "otel/opentelemetry-collector-contrib"
  }
  
  set {
    name  = "fullnameOverride"
    value = "otel-collector"
  }

  set {
    name  = "image.tag"
    value = "0.104.0"
  }

  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600
  depends_on = [helm_release.prometheus, helm_release.loki, helm_release.jaeger]

  values = [
    yamlencode({
      mode = "deployment"
      
      # Removemos o bloco 'telemetry' externo que causou o erro de schema
      
      config = {
        extensions = {
          health_check = {
            endpoint = "0.0.0.0:13133"
          }
        }

        receivers = {
          otlp = {
            protocols = {
              grpc = { endpoint = "0.0.0.0:4317" }
              http = { endpoint = "0.0.0.0:4318" }
            }
          }
        }

        processors = {
          batch = {
            send_batch_size = 1000
            timeout         = "10s"
          }
          memory_limiter = {
            check_interval  = "5s"
            limit_mib       = 250
            spike_limit_mib = 50
          }
          resourcedetection = {
            detectors = ["env", "system"]
          }
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
            endpoint = "jaeger.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:4317"
            tls = { insecure = true }
          }
          datadog = {
            api = {
              key  = "652f13a64d96b3cdb72aa07516d7f9a5"
              site = "datadoghq.com"
            }
          }
        }

        service = {
          # Desativamos a telemetria interna aqui dentro para evitar conflitos de porta
          telemetry = {
            metrics = {
              level = "none"
            }
          }

          extensions = ["health_check"]
          
          pipelines = {
            metrics = {
              receivers  = ["otlp"]
              processors = ["resourcedetection","memory_limiter", "batch"]
              exporters  = ["prometheusremotewrite","datadog"]
            }
            logs = {
              receivers  = ["otlp"]
              processors = ["resourcedetection","memory_limiter", "batch"]
              exporters  = ["loki","datadog"]
            }
            traces = {
              receivers  = ["otlp"]
              processors = ["resourcedetection","memory_limiter", "batch"]
              exporters  = ["otlp/jaeger","datadog"]
            }
          }
        }
      }
    })
  ]
}
# ==========================================================
# 8. METRICS SERVER (Habilita o 'kubectl top')
# ==========================================================
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system" # Geralmente instalado no kube-system

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

# ==========================================================
# 9. DATADOG AGENT (Âncora de Infraestrutura)
# ==========================================================
resource "helm_release" "datadog_agent" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name # Usa o namespace 'observabilidade' 
  timeout    = 600

  set_sensitive {
    name  = "datadog.apiKey"
    value = "652f13a64d96b3cdb72aa07516d7f9a5" # Chave idêntica à usada no OTel
  }

  set {
    name  = "datadog.confd.redisdb\\.yaml"
    value = yamlencode({
      instances = [
        {
          # O host deve ser o endpoint do ElastiCache (que você pode obter do output do outro módulo)
          host = var.redis_endpoint
          port = 6379
          # Se não houver token, garantimos que o Agent saiba que a autenticação é vazia
          username = ""
          password = ""
          # Desabilita comandos de admin que o ElastiCache bloqueia e causam erro de 'Auth'
          collect_client_list = false
        }
      ]
    })
  }
  set {
    name  = "datadog.site"
    value = "datadoghq.com"
  }

  # Habilita a coleta de logs e métricas do K8s para estabilizar o Service Map
  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  # Essencial para correlacionar os Traces do OTel com a Infraestrutura
  set {
    name  = "datadog.apm.portEnabled"
    value = "true"
  }

  # Ativa o Cluster Agent para monitorar o estado geral do cluster
  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  # Configuração para evitar conflitos de porta com o Metrics Server 
  set {
    name  = "datadog.kubelet.tlsVerify"
    value = "false"
  }
}
