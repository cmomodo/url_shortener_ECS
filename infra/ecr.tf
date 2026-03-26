# ECR repositories — one per service
resource "aws_ecr_repository" "api" {
  name                 = "url-shortener/api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
# ECR repositories — one per service
resource "aws_ecr_repository" "api" {
  name                 = "url-shortener/dashboard"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
# ECR repositories — one per service
resource "aws_ecr_repository" "api" {
  name                 = "url-shortener/dashboard"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECR repositories — one per service
resource "aws_ecr_repository" "api" {
  name                 = "url-shortener/worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
