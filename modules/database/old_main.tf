# DB Subnet Group para o RDS
resource "aws_db_subnet_group" "rds_sg" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.private_subnets

  tags = { Name = "${var.project_name}-rds-subnet-group" }
}

# 1. Três Instâncias RDS (PostgreSQL) - [cite: 35]
resource "aws_db_instance" "postgresql" {
  count                  = 3
  identifier             = "${var.project_name}-db-${count.index}"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro" # Econômico para Academy
  allocated_storage      = 20
  db_name                = "togglemaster_db_${count.index}"
  username               = "adminuser"
  password               = "password123" # Em produção, use Secrets Manager [cite: 20]
  db_subnet_group_name   = aws_db_subnet_group.rds_sg.name
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [var.db_sg_id]

  tags = { Name = "${var.project_name}-rds-${count.index}" }
}

# 2. Cluster ElastiCache (Redis) - [cite: 36]
resource "aws_elasticache_subnet_group" "redis_sg" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = var.private_subnets
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.redis_sg.name
  security_group_ids   = [var.db_sg_id]
}

# 3. Tabela DynamoDB (ToggleMasterAnalytics) - 
resource "aws_dynamodb_table" "analytics" {
  name           = "ToggleMasterAnalytics"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = { Name = "ToggleMasterAnalytics" }
}