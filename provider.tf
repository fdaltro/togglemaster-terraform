terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Configuração do Backend Remoto no seu bucket 
  backend "s3" {
    bucket = "togglemaster-terraform-state-grupox"
    key    = "fase3/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}