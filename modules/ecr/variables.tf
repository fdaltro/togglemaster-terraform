variable "project_name" {}
variable "service_names" {
  type    = list(string)
  default = ["auth", "flag", "targeting", "evaluation", "analytics"]
}