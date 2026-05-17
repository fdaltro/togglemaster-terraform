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
    # ADICIONADO: Provider necessário para manifestos complexos do ArgoCD
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }

  backend "s3" {
    bucket = "togglemaster-terraform-state-fase4"
    key    = "fase3/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# --- Autenticação Dinâmica ----


provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}


# ADICIONADO: Configuração do provider kubectl
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false # VITAL: Impede que o Terraform tente ler o kubeconfig local no plan
}


# PROVIDER DO DATADOG (Requisito para criar Alertas via Código)
provider "datadog" {
  api_key = "652f13a64d96b3cdb72aa07516d7f9a5"
  app_key = "ddapp_q7r7xtm4M6MYYBmEB9PHecRIwRzq0ng7wb"
  site    = "datadoghq.com"
}