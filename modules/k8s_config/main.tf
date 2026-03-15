# ==========================================================
# CONFIGURAÇÕES DO KUBERNETES (CONFIGMAPS E SECRETS)
# ==========================================================

# --- SERVIÇO: ANALYTICS ---
resource "kubernetes_config_map" "analytics_config" {
  metadata {
    name      = "analytics-config"
    namespace = "togglemaster"
  }
  data = {
    AWS_SQS_URL        = var.sqs_queue_url
    AWS_DYNAMODB_TABLE = "ToggleMasterAnalytics"
    AUTH_SERVICE_URL   = "http://auth-service:8001"
    PORT               = "8005"
  }
}

# --- SERVIÇO: AUTH ---
resource "kubernetes_config_map" "auth_config" {
  metadata {
    name      = "auth-config"
    namespace = "togglemaster"
  }
  data = {
    PORT = "8001"
  }
}

resource "kubernetes_secret" "auth_secret" {
  metadata {
    name      = "auth-secret"
    namespace = "togglemaster"
  }
  data = {
    DATABASE_URL = "postgres://adminuser:password123@${var.rds_endpoints["auth"]}/auth_db"
    MASTER_KEY   = "admin-secreto-123"
  }
  type = "Opaque"
}

# --- SERVIÇO: EVALUATION ---
resource "kubernetes_config_map" "evaluation_config" {
  metadata {
    name      = "evaluation-config"
    namespace = "togglemaster"
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
    namespace = "togglemaster"
  }
  data = {
    SERVICE_API_KEY = "admin-secreto-123"
  }
  type = "Opaque"
}

# --- SERVIÇO: FLAGS ---
resource "kubernetes_config_map" "flag_config" {
  metadata {
    name      = "flag-service-config"
    namespace = "togglemaster"
  }
  data = {
    AUTH_SERVICE_URL = "http://auth-service:8001"
    PORT             = "8002"
  }
}

resource "kubernetes_secret" "flag_secret" {
  metadata {
    name      = "flag-service-secret"
    namespace = "togglemaster"
  }
  data = {
    DATABASE_URL = "postgres://adminuser:password123@${var.rds_endpoints["flags"]}/flags_db"
    MASTER_KEY   = "admin-secreto-123"
  }
  type = "Opaque"
}

# --- SERVIÇO: TARGETING ---
resource "kubernetes_config_map" "targeting_config" {
  metadata {
    name      = "targeting-service-config"
    namespace = "togglemaster"
  }
  data = {
    AUTH_SERVICE_URL = "http://auth-service:8001"
    PORT             = "8003"
  }
}

resource "kubernetes_secret" "targeting_secret" {
  metadata {
    name      = "targeting-db-secret"
    namespace = "togglemaster"
  }
  data = {
    DATABASE_URL = "postgres://adminuser:password123@${var.rds_endpoints["targeting"]}/targeting_db"
    MASTER_KEY   = "admin-secreto-123"
  }
  type = "Opaque"
}