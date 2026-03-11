locals {
  # Mapeamento para garantir os nomes específicos solicitados
  db_specs = [
    { name = "auth_db",      id = "auth" },
    { name = "flags_db",     id = "flags" },
    { name = "targeting_db", id = "targeting" }
  ]
}

# DB Subnet Group para o RDS
resource "aws_db_subnet_group" "rds_sg" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.private_subnets
  tags       = { Name = "${var.project_name}-rds-subnet-group" }
}

# 1. Três Instâncias RDS (PostgreSQL) com nomes específicos
resource "aws_db_instance" "postgresql" {
  count                  = 3
  
  # Identificador na AWS (ex: togglemaster-db-auth)
  identifier             = "${var.project_name}-db-${local.db_specs[count.index].id}"
  
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  
  # Nome da base de dados (ex: auth_db)
  db_name                = local.db_specs[count.index].name
  
  username               = "adminuser"
  password               = "password123"
  db_subnet_group_name   = aws_db_subnet_group.rds_sg.name
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [var.db_sg_id]

  tags = { Name = "${var.project_name}-rds-${local.db_specs[count.index].id}" }
}

# 2. Cluster ElastiCache (Redis)
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

# 3. Tabela DynamoDB
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