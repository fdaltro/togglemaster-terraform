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

  # Configuração do Backend Remoto (Mantido conforme seu original)
  backend "s3" {
    bucket = "togglemaster-terraform-state-grupox"
    key    = "fase3/terraform.tfstate"
    region = "us-east-1"
  }
}

# Provedor AWS Principal
provider "aws" {
  region = var.region
}

# --- Configurações Dinâmicas para Kubernetes e Helm ---

# Busca os dados do cluster EKS criado pelo seu módulo 'eks'
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

# Busca o token de autenticação temporário para o cluster
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Provedor Kubernetes: Permite criar Namespaces, Secrets e ConfigMaps
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Provedor Helm: Permite a instalação do ArgoCD
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}


