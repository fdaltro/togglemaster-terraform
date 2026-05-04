# ==========================================================
# 1. CLUSTER EKS
# ==========================================================
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.lab_role_arn # Utilizando a LabRole obrigatória do Academy

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  tags = {
    Name = var.cluster_name
  }
}

# ==========================================================
# 2. NODE GROUP (WORKER NODES)
# ==========================================================
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.lab_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"] 

  tags = {
    Name = "${var.cluster_name}-node"
  }
}
/*
# ==========================================================
# 3. INSTALAÇÃO DE ADD-ONS
# ==========================================================

resource "aws_eks_addon" "local_instance_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ec2-local-instance-store-csi-driver"
  addon_version               = "v1.0.0-eksbuild.1"
  resolve_conflicts_on_update = "OVERWRITE"

}
