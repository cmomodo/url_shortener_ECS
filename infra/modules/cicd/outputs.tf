output "github_connection_arn" {
  value       = aws_codestarconnections_connection.github.arn
  description = "CodeStar/CodeConnections GitHub connection ARN (authorize once in the console)."
}

output "pipeline_name" {
  value       = aws_codepipeline.container_deploy.name
  description = "Container-deploy pipeline name."
}

output "artifact_bucket" {
  value       = aws_s3_bucket.artifacts.bucket
  description = "Pipeline artifact bucket name."
}
