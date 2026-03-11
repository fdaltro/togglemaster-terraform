locals {
  # Mapeamento dos nomes para cada índice do count
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

# 1. Três Instâncias RDS (PostgreSQL)
resource "aws_db_instance" "postgresql" {
  count                  = 3
  
  # Usa o ID específico para o identificador da AWS (ex: togglemaster-db-auth)
  identifier             = "${var.project_name}-db-${local.db_specs[count.index].id}"
  
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  
  # Usa o nome específico solicitado para a base de dados
  db_name                = local.db_specs[count.index].name
  
  username               = "adminuser"
  password               = "password123"
  db_subnet_group_name   = aws_db_subnet_group.rds_sg.name
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [var.db_sg_id]

  tags = { 
    Name = "${var.project_name}-rds-${local.db_specs[count.index].id}" 
  }
}