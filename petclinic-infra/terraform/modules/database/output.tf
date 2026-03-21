output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_creds.arn
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}
