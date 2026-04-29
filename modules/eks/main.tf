# Cluster EKS
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.lab_role_arn # Utilizando a LabRole fornecida

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  tags = {
    Name = var.cluster_name
  }
}

# Ativar Plugin EKS Add-ons para permitir discos EBS
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  # O ARN LabRole
  service_account_role_arn    = "arn:aws:iam::504491092699:role/LabRole" 
  resolve_conflicts_on_update = "PRESERVE"
}

# Node Group (Trabalhadores)
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.lab_role_arn # Utilizando a LabRole fornecida
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"] # Recomendado para suportar os 5 microsserviços

  tags = {
    Name = "${var.cluster_name}-node"
  }
}