terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

# Configura a integração no lado do Datadog
resource "datadog_integration_aws" "core" {
  account_id = var.aws_account_id
  role_name  = var.lab_role_name
  
  # Como não podemos editar a Trust Relationship da LabRole, 
  # desativamos a verificação de STS se necessário (opção dependente da versão do provider)
  host_resource_collection_enabled = true
  
  filter_tags = ["project:togglemaster"]
}
