# 1. Namespace isolado para a stack de monitoramento
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "observabilidade"
  }
}

# 2. StorageClass para o Driver de Instância Local (EC2 Instance Store)
# Esta classe utiliza o driver que você ativou manualmente no console
resource "kubernetes_storage_class" "local_instance_sc" {
  metadata {
    name = "local-instance-sc"
  }
  storage_provisioner    = "instance-store.csi.aws.com" 
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
}

# 3. Prometheus: Coleta de métricas e Alertmanager
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  # Persistência do Prometheus Server usando o driver local
  set {
    name  = "server.persistentVolume.enabled"
    value = "true"
  }
  set {
    name  = "server.persistentVolume.storageClass"
    value = "local-instance-sc"
  }
  set {
    name  = "server.persistentVolume.size"
    value = "8Gi"
  }

  # Persistência do Alertmanager usando o driver local
  set {
    name  = "alertmanager.persistentVolume.enabled"
    value = "true"
  }
  set {
    name  = "alertmanager.persistentVolume.storageClass"
    value = "local-instance-sc"
  }

  set {
    name  = "pushgateway.persistentVolume.enabled"
    value = "true"
  }

  # Injeção de configuração básica para evitar o erro de arquivo ausente no Alertmanager
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

# 4. Loki: Agregador de Logs
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
    value = "local-instance-sc"
  }
  set {
    name  = "loki.persistence.size"
    value = "5Gi"
  }
}

# 5. Grafana: Dashboards e Visualização
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
    value = "local-instance-sc"
  }

  set {
    name  = "adminPassword"
    value = "admin123"
  }

  # Configuração automática de Data Sources
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
