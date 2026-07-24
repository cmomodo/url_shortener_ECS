resource "aws_ecr_repository" "api" {
  #checkov:skip=CKV_AWS_136: Existing development repository uses ECR-managed AES-256 encryption; changing encryption would replace it and delete stored images.
  name                 = "url-shortener/api"
  image_tag_mutability = "IMMUTABLE"

  lifecycle {
    prevent_destroy = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "dashboard" {
  #checkov:skip=CKV_AWS_136: Existing development repository uses ECR-managed AES-256 encryption; changing encryption would replace it and delete stored images.
  name                 = "url-shortener/dashboard"
  image_tag_mutability = "IMMUTABLE"

  lifecycle {
    prevent_destroy = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "worker" {
  #checkov:skip=CKV_AWS_136: Existing development repository uses ECR-managed AES-256 encryption; changing encryption would replace it and delete stored images.
  name                 = "url-shortener/worker"
  image_tag_mutability = "IMMUTABLE"

  lifecycle {
    prevent_destroy = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "dashboard" {
  repository = aws_ecr_repository.dashboard.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "worker" {
  repository = aws_ecr_repository.worker.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

output "api_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "dashboard_repository_url" {
  value = aws_ecr_repository.dashboard.repository_url
}

output "worker_repository_url" {
  value = aws_ecr_repository.worker.repository_url
}
