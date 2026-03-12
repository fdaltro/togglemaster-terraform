terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    bucket = "togglemaster-terraform-state-grupox"
    key    = "fase3/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# --- Autenticação Dinâmica ---

# O Token ainda precisa ser via data source, mas ele vai esperar 
# o nome do cluster vir do módulo 'eks' [cite: 1, 2]
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Provedor Kubernetes usando os outputs do seu módulo diretamente
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Provedor Helm usando a mesma lógica para o ArgoCD
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}