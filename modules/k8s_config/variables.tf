variable "region" {
  type = string
}

variable "rds_endpoints" {
  type = map(string)
}

variable "redis_endpoint" {
  type = string
}

variable "sqs_queue_url" {
  type = string
}

# Novas variáveis para as credenciais do GitHub Actions Secrets
variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "aws_session_token" {
  type = string
}