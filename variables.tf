variable "region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "togglemaster"
}

variable "cluster_name" {
  default = "togglemaster-eks"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "aws_access_key" {
  description = "AWS Access Key vinda do GitHub Secrets"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Key vinda do GitHub Secrets"
  type        = string
}

variable "aws_session_token" {
  description = "AWS Session Token vindo do GitHub Secrets"
  type        = string
}