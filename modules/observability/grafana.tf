# ==========================================================
# 1. PASTA DE MONITORAMENTO NO GRAFANA
# ==========================================================
resource "grafana_folder" "togglemaster" {
  title = "ToggleMaster - Produção"
}

# ==========================================================
# 2. PONTO DE CONTATO - INTEGRAÇÃO COM PAGERDUTY
# ==========================================================
resource "grafana_contact_point" "pagerduty" {
  name = "PagerDuty-Grupo04"

  pagerduty {
    # Substitua pela Integration Key copiada do seu PagerDuty
    integration_key = "b2081df169994f03c0212edf54034fbb"
    severity        = "critical"
    class           = "ping failure"
    component       = "auth-service"
  }
}

# ==========================================================
# 3. DASHBOARD AUTOMÁTICO COM OS GRÁFICOS E ALERTAS
# ==========================================================
resource "grafana_dashboard" "togglemaster_dashboard" {
  folder      = grafana_folder.togglemaster.uid
  config_json = jsonencode({
    title         = "ToggleMaster - Dashboard de Operações (Grupo 04)"
    uid           = "togglemaster-ops-metrics"
    refresh       = "5s"
    schemaVersion = 36
    
    panels = [
      {
        type  = "timeseries"
        title = "Volume de Requisições - auth-service"
        id    = 1
        gridPos = { h = 8, w = 12, x = 0, y = 0 }
        targets = [
          {
            datasource = { type = "prometheus", uid = "prometheus" }
            expr       = "sum(rate(http_server_request_duration_seconds_count{service_name=\"auth-service\"}[5m]))"
            refId      = "A"
          }
        ]
      },
      {
        type  = "timeseries"
        title = "Taxa de Erro HTTP 5xx (%)"
        id    = 2
        gridPos = { h = 8, w = 12, x = 12, y = 0 }
        targets = [
          {
            datasource = { type = "prometheus", uid = "prometheus" }
            expr       = "sum(rate(http_server_request_duration_seconds_count{service_name=\"auth-service\", http_response_status_code=~\"5..\"}[5m])) / sum(rate(http_server_request_duration_seconds_count{service_name=\"auth-service\"}[5m]))"
            refId      = "A"
          }
        ]
      }
    ]
  })
}

# ==========================================================
# 4. REGRA DE ALERTA INTELIGENTE (PROMETHEUS ENGINE)
# ==========================================================
resource "grafana_rule_group" "auth_service_alerts" {
  name             = "alertas-auth-service"
  folder_uid       = grafana_folder.togglemaster.uid
  interval_seconds = 30 # Avalia a regra a cada 1 minuto

  rule {
    name           = "[ToggleMaster] Taxa de Erro HTTP 5xx Crítica - auth-service"
    condition      = "C" # Aponta para a expressão matemática final (C)
    for            = "5m" # Precisa persistir por 5 minutos para disparar

    # A: Coleta o valor atual da taxa de erro vindo do OpenTelemetry via Prometheus
    data {
      ref_id = "A"
      relative_time_range { from = 300, to = 0 }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr = "sum(rate(http_server_request_duration_seconds_count{service_name=\"auth-service\", http_response_status_code=~\"5..\"}[5m])) / sum(rate(http_server_request_duration_seconds_count{service_name=\"auth-service\"}[5m]))"
      })
    }

    # B: Reduz a série temporal de dados de "A" para pegar o último ponto gerado (Last Value)
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "reduce"
        expression = "A"
        reducer    = "last"
      })
    }

    # C: Valida se a expressão matemática do Último Ponto (B) é maior que 5% (0.05)
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "math"
        expression = "$B > 0.05"
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Alerting"

    annotations = {
      summary     = "A taxa de erro HTTP 5xx do auth-service ultrapassou 5%"
      description = "O microsserviço auth-service está apresentando instabilidade severa. Acionando plantonista via PagerDuty."
    }
  }
}