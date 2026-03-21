output "application_load_balancer" {
  value = aws_security_group.alb_sequrity_group
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "mysql_db_sg_id" {
  value = aws_security_group.mysql_db.id
}