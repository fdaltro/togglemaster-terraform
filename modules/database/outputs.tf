output "rds_endpoints" {
  description = "Endpoints dos bancos de dados mapeados por serviço"
  value = {
    auth      = aws_db_instance.postgresql[0].endpoint
    flags     = aws_db_instance.postgresql[1].endpoint
    targeting = aws_db_instance.postgresql[2].endpoint
  }
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}