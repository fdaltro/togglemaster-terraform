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

# -----------------------------
# ADD-ONS OFICIAIS DO EKS
# -----------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  # ALTERADO PARA OVERWRITE
  resolve_conflicts_on_update = "OVERWRITE" 

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  # ALTERADO PARA OVERWRITE
  resolve_conflicts_on_update = "OVERWRITE" 

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  # ALTERADO PARA OVERWRITE
  resolve_conflicts_on_update = "OVERWRITE" 

  # ALTERADO PARA DEPENDER DO NODE GROUP (MUITO IMPORTANTE)
  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.lab_role_arn

  # ALTERADO PARA OVERWRITE
  resolve_conflicts_on_update = "OVERWRITE" 

  # ALTERADO PARA DEPENDER DO NODE GROUP (MUITO IMPORTANTE)
  depends_on = [aws_eks_node_group.main]
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