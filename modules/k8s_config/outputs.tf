output "config_status" {
  description = "Status do deploy das configurações do Kubernetes"
  value       = "ConfigMaps e Secrets aplicados com sucesso no namespace togglemaster"
}

output "database_urls_configured" {
  description = "Lista de serviços que tiveram o banco de dados configurado"
  value       = keys(var.rds_endpoints)
}