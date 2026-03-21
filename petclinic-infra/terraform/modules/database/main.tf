resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}_db_subnet_group"
  subnet_ids = var.private_subnet_ids
  tags = {
    Name = "${var.project_name}_db_subnet_group"
  }
}

resource "aws_db_instance" "mysql" {
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = var.db_name
  username          = var.db_username
  password          = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.mysql_db_sg_id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  tags = {
    Name = "${var.project_name}_mysql_db"
  }
}

resource "aws_secretsmanager_secret" "db_creds" {
  name                    = "${var.project_name}_db_credentials"
  description             = "Database credentials for ${var.project_name}"
  recovery_window_in_days = 0
  tags = {
    Name = "${var.project_name}_db_credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_creds_version" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    host     = aws_db_instance.mysql.address
    port     = aws_db_instance.mysql.port
    dbname   = aws_db_instance.mysql.db_name
    username = aws_db_instance.mysql.username
    password = aws_db_instance.mysql.password
  })
}
