# --- ENDPOINTS DO CLUSTER EKS ---
output "eks_cluster_endpoint" {
  description = "Endpoint para o API Server do Kubernetes"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "Nome do Cluster para configurar o kubectl"
  value       = module.eks.cluster_name
}

# --- ENDPOINTS DOS BANCOS DE DADOS ---
output "rds_endpoints" {
  description = "Lista de endereços das 3 instâncias PostgreSQL"
  value       = module.database.rds_endpoints
}

output "redis_endpoint" {
  description = "Endereço do cluster ElastiCache Redis"
  value       = module.database.redis_endpoint
}

# --- URLs DOS REPOSITÓRIOS ECR ---
output "ecr_repository_urls" {
  description = "URLs para o login do Docker e Push das imagens"
  value       = module.ecr.repository_urls
}

# --- FILA SQS ---
output "sqs_queue_url" {
  description = "URL da fila SQS para os microsserviços"
  value       = module.sqs.sqs_url
}

# --- Argo CD ---
output "argocd_endpoint" {
  value = module.argocd.argocd_url
}

output "argocd_admin_password" {
  value     = module.argocd.argocd_password
  sensitive = true
}