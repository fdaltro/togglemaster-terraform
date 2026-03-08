# Importação da LabRole existente para associar aos recursos 
data "aws_iam_role" "labrole" {
  name = "LabRole"
}