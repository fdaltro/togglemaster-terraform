variable "redis_endpoint" {
  type        = string
  description = "Endpoint do ElastiCache Redis"
  default     = "" # Opcional: evita erro se o redis ainda não existir
}
