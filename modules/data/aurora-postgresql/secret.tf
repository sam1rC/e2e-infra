# Usuario de aplicación ≠ maestro: el secreto maestro (gestionado por RDS) es solo para administración y
# migraciones; las tareas leen app_runtime, cuyo rol SQL crea el bootstrap de la fase 8.4.
module "app_secret" {
  source = "../postgres-app-secret"

  environment          = var.environment
  name                 = local.name
  vpc_id               = var.vpc_id
  db_security_group_id = aws_security_group.this.id
  db_port              = var.port
  kms_key_arn          = var.kms_key_arn
  db_host              = aws_rds_cluster.this.endpoint
  db_name              = var.database_name
  master_secret_arn    = aws_rds_cluster.this.master_user_secret[0].secret_arn
  rotation             = var.app_secret_rotation

  recovery_window_in_days = var.app_secret_recovery_window_in_days
  log_retention_days      = var.log_retention_days

  tags = var.tags
}
