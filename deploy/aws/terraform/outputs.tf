output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "api_url" {
  value = var.api_domain_name != "" ? "${local.use_tls ? "https" : "http"}://${var.api_domain_name}" : "${local.use_tls ? "https" : "http"}://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.main.repository_url
}

output "db_endpoint" {
  value = aws_db_instance.main.address
}

output "database_url_secret_arn" {
  value = aws_secretsmanager_secret.db_url.arn
}
