# ==========================================================
# 1. Rede
# ==========================================================
module "network" {
  source       = "./modules/vpc"
  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  cluster_name = var.cluster_name
}

# ==========================================================
# 2. Bancos de Dados
# ==========================================================
module "database" {
  source          = "./modules/database"
  project_name    = var.project_name
  private_subnets = module.network.private_subnets
  db_sg_id        = module.network.db_security_group_id # Você precisará criar este SG no módulo VPC
}

# ==========================================================
# 3. Cluster EKS (Requisito Academy)
# ==========================================================
module "eks" {
  source       = "./modules/eks"
  cluster_name = var.cluster_name
  subnet_ids   = module.network.public_subnets
  lab_role_arn = "arn:aws:iam::174935208848:role/LabRole" # Seu ARN fornecido
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name # Nome que vem do seu módulo EKS
}

# ==========================================================
# 4. Mensageria (Requisito 4 da Fase 3)
# ==========================================================
module "sqs" {
  source       = "./modules/sqs"
  project_name = var.project_name
}

# ==========================================================
# 5. Repositórios de Imagens (Requisito 5 da Fase 3)
# ==========================================================
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

# ==========================================================
# 6. Deploy do ArgoCD via Helm
# ==========================================================
module "argocd" {
  source     = "./modules/argocd"
  depends_on = [module.eks] # Garante que o cluster exista antes do Helm
}

# ==========================================================
# 7. Configurações de Aplicativos no Kubernetes
# ===========================================================
module "k8s_config" {
  source          = "./modules/k8s_config"
  region          = var.region
  rds_endpoints   = module.database.rds_endpoints
  redis_endpoint  = module.database.redis_endpoint
  sqs_queue_url   = module.sqs.sqs_url
  aws_access_key    = var.aws_access_key
  aws_secret_key    = var.aws_secret_key
  aws_session_token = var.aws_session_token

  depends_on = [module.eks, module.argocd]
}