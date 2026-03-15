# ==========================================================
# 1. DEFINIÇÃO DO NAMESPACE
# ==========================================================
resource "kubernetes_namespace" "togglemaster" {
  metadata {
    name = "togglemaster"
  }
}

# ==========================================================
# 2. CONFIGURAÇÕES DO SERVIÇO: ANALYTICS
# ==========================================================
resource "kubernetes_config_map" "analytics_config" {
  metadata {
    name      = "analytics-config"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name
  }

  data = {
    AWS_SQS_URL        = var.sqs_queue_url
    AWS_DYNAMODB_TABLE = "ToggleMasterAnalytics"
    AUTH_SERVICE_URL   = "http://auth-service:8001"
    PORT               = "8005"
  }
}

# ==========================================================
# 3. CONFIGURAÇÕES DO SERVIÇO: AUTH
# ==========================================================
resource "kubernetes_config_map" "auth_config" {
  metadata {
    name      = "auth-config"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name
  }

  data = {
    PORT = "8001"
  }
}

resource "kubernetes_secret" "auth_secret" {
  metadata {
    name      = "auth-secret"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name
  }

  data = {
    DATABASE_URL = "postgres://adminuser:password123@${var.rds_endpoints["auth"]}/auth_db"
    MASTER_KEY   = "admin-secreto-123"
  }

  type = "Opaque"
}

# ==========================================================
# 4. CONFIGURAÇÕES DO SERVIÇO: EVALUATION
# ==========================================================
resource "kubernetes_config_map" "evaluation_config" {
  metadata {
    name      = "evaluation-config"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name
  }

  data = {
    REDIS_URL             = "redis://${var.redis_endpoint}:6379"
    AWS_SQS_URL           = var.sqs_queue_url
    AWS_REGION            = var.region
    AUTH_SERVICE_URL      = "http://auth-service:8001"
    FLAG_SERVICE_URL      = "http://flag-service:8002"
    TARGETING_SERVICE_URL = "http://targeting-service:8003"
    PORT                  = "8004"
  }
}

resource "kubernetes_secret" "evaluation_secret" {
  metadata {
    name      = "evaluation-secret"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name
  }

  data = {
    SERVICE_API_KEY = "admin-secreto-123"
  }

  type = "Opaque"
}

# ==========================================================
# 5. CONFIGURAÇÕES DO SERVIÇO: FLAGS
# ==========================================================
resource "kubernetes_config_map" "flag_config" {
  metadata {
    name      = "flag-service-config"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name
  }

  data = {
    AUTH_SERVICE_URL = "http://auth-service:8001"
    PORT             = "8002"
  }
}

resource "kubernetes_secret" "flag_secret" {
  metadata {
    name      = "flag-service-secret"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name
  }

  data = {
    DATABASE_URL = "postgres://adminuser:password123@${var.rds_endpoints["flags"]}/flags_db"
    MASTER_KEY   = "admin-secreto-123"
  }

  type = "Opaque"
}

# ==========================================================
# 6. CONFIGURAÇÕES DO SERVIÇO: TARGETING
# ==========================================================
resource "kubernetes_config_map" "targeting_config" {
  metadata {
    name      = "targeting-service-config"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name
  }

  data = {
    AUTH_SERVICE_URL = "http://auth-service:8001"
    PORT             = "8003"
  }
}

resource "kubernetes_secret" "targeting_secret" {
  metadata {
    name      = "targeting-db-secret"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name
  }

  data = {
    DATABASE_URL = "postgres://adminuser:password123@${var.rds_endpoints["targeting"]}/targeting_db"
    MASTER_KEY   = "admin-secreto-123"
  }

  type = "Opaque"
}