terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

# Este recurso configura o Datadog para "olhar" para sua conta AWS
resource "datadog_integration_aws_account" "datadog_integration" {
  aws_account_id = var.aws_account_id
  aws_partition  = "aws"
  
  aws_regions {
    include_all = true
  }

  auth_config {
    aws_auth_config_role {
      # Na Academy, usamos a role que já existe
      role_name = "LabRole" 
    }
  }

  resources_config {
    cloud_security_posture_management_collection = false # Desativado para evitar erros de permissão na Academy
    extended_collection                          = true
  }

  metrics_config {
    namespace_filters {
      # Filtra apenas o que importa para seus 5 serviços
      include_only = ["AWS/SQS", "AWS/DynamoDB", "AWS/ElastiCache", "AWS/Lambda"]
    }
  }
}
