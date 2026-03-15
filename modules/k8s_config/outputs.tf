variable "region" {
  description = "Região da AWS utilizada para o deploy"
  type        = string
}

variable "rds_endpoints" {
  description = "Mapa contendo os endpoints do RDS indexados por serviço (auth, flags, targeting)"
  type        = map(string)
}

variable "redis_endpoint" {
  description = "Endpoint (host) do cluster ElastiCache Redis"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL da fila SQS gerada pelo módulo de mensageria"
  type        = string
}