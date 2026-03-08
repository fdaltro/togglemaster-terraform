# 1. Rede
module "network" {
  source       = "./modules/vpc"
  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  cluster_name = var.cluster_name
}

# 2. Bancos de Dados
module "database" {
  source          = "./modules/database"
  project_name    = var.project_name
  private_subnets = module.network.private_subnets
  db_sg_id        = module.network.db_security_group_id # Você precisará criar este SG no módulo VPC
}

# 3. Cluster EKS (Requisito Academy)
module "eks" {
  source       = "./modules/eks"
  cluster_name = var.cluster_name
  subnet_ids   = module.network.private_subnets
  lab_role_arn = "arn:aws:iam::174935208848:role/LabRole" # Seu ARN fornecido
}

# 4. Mensageria (Requisito 4 da Fase 3)
module "sqs" {
  source       = "./modules/sqs"
  project_name = var.project_name
}

# 5. Repositórios de Imagens (Requisito 5 da Fase 3) [cite: 40]
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}