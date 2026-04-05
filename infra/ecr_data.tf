data "aws_ecr_repository" "api" {
  name = "url-shortener/api"
}

data "aws_ecr_repository" "dashboard" {
  name = "url-shortener/dashboard"
}

data "aws_ecr_repository" "worker" {
  name = "url-shortener/worker"
}
