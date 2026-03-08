resource "aws_ecr_repository" "microservices" {
  for_each             = toset(var.service_names)
  name                 = "${var.project_name}-${each.value}"
  image_tag_mutability = "IMMUTABLE" # Garante que as tags (commit hash) não sejam sobrescritas [cite: 63]

  image_scanning_configuration {
    scan_on_push = true # Requisito de scan de vulnerabilidades 
  }

  tags = {
    Name = "${var.project_name}-${each.value}"
  }
}