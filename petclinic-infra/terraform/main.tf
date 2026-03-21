module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}

module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

module "database" {
  source             = "./modules/database"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  mysql_db_sg_id     = module.security.mysql_db_sg_id
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
}

module "compute" {
  source            = "./modules/compute"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_sg_id         = module.security.app_sg_id
  alb_sg_id         = module.security.application_load_balancer.id
  key_name          = var.key_name
  db_secret_arn     = module.database.db_secret_arn
  jenkins_ingress_ip = var.jenkins_ingress_ip
}