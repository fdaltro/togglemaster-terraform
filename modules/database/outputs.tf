output "rds_endpoints" {
  description = "Endpoints dos bancos de dados mapeados por serviço"
  value       = { for k, v in aws_db_instance.postgresql : k => v.endpoint }
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}