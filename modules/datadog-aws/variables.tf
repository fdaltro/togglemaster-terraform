variable "datadog_api_key" {
  type        = string
  description = "Datadog API Key"
}

variable "datadog_app_key" {
  type        = string
  description = "Datadog App Key"
}

variable "aws_account_id" {
  type        = string
  description = "ID da conta AWS Academy"
  default     = "504491092699"
}

variable "lab_role_name" {
  type        = string
  description = "Nome da role pré-existente na Academy"
  default     = "LabRole"
}
