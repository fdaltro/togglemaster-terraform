variable "region" { type = string }
variable "rds_endpoints" { type = map(string) }
variable "redis_endpoint" { type = string }
variable "sqs_queue_url" { type = string }