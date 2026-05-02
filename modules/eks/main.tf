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
# 2. ADD-ONS ESSENCIAIS (REDE E DNS)
# Mantemos apenas o básico para o cluster operar sem erros de comunicação.
# ==========================================================

# VPC CNI: Responsável por atribuir IPs da VPC aos Pods
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE" # Resolve conflitos de permissão no Academy[cite: 9]
  depends_on                  = [aws_eks_cluster.main]
}

# Kube-Proxy: Gerencia as regras de rede (Services) do Kubernetes[cite: 9]
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"[cite: 9]
  depends_on                  = [aws_eks_cluster.main]
}

# CoreDNS: Sistema de nomes interno (essencial para microsserviços se acharem)[cite: 9]
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"[cite: 9]
  
  # O CoreDNS só estabiliza após os nós (Worker Nodes) estarem prontos[cite: 9]
  depends_on = [aws_eks_node_group.main] 
}

# ==========================================================
# 3. NODE GROUP (WORKER NODES)
# As máquinas onde seus containers realmente serão executados.
# ==========================================================
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.lab_role_arn # Utilizando a LabRole para permissões de execução[cite: 9]
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  # t3.medium é o equilíbrio ideal para rodar 5 microsserviços + ArgoCD[cite: 9]
  instance_types = ["t3.medium"] 

  tags = {
    Name = "${var.cluster_name}-node"
  }
}