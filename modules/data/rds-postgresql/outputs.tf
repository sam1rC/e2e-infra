output "instance_arn" {
  description = "ARN de la instancia."
  value       = aws_db_instance.this.arn
}

output "instance_id" {
  description = "Identificador de la instancia."
  value       = aws_db_instance.this.id
}

output "resource_id" {
  description = "ID de recurso de la instancia (db-XXXX), el que usan los ARN de rds-db:connect."
  value       = aws_db_instance.this.resource_id
}

output "iam_auth_resource_arn_prefix" {
  description = "Prefijo del ARN de rds-db:connect (arn:...:dbuser:<resource_id>): añade /<usuario_sql> para dar acceso por IAM a un usuario concreto."
  value       = "arn:${data.aws_partition.current.partition}:rds-db:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.this.resource_id}"
}

output "endpoint" {
  description = "Nombre DNS de la instancia (sin puerto)."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Puerto de PostgreSQL."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Base de datos inicial."
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "Security group de la base de datos (sin reglas de salida)."
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "ARN del secreto maestro gestionado por RDS (solo administración y migraciones)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "app_secret_arn" {
  description = "ARN del secreto app_runtime que leen las aplicaciones."
  value       = module.app_secret.secret_arn
}

output "rotation_lambda_arn" {
  description = "ARN de la función de rotación del secreto de la aplicación; null si no hay rotación."
  value       = module.app_secret.rotation_lambda_arn
}

output "rotation_security_group_id" {
  description = "Security group de la función de rotación; null si no hay rotación. Autorízalo en el endpoint de Secrets Manager (allowed_security_group_ids de vpc-endpoints)."
  value       = module.app_secret.rotation_security_group_id
}

output "log_group_name" {
  description = "Log group de los logs de PostgreSQL."
  value       = aws_cloudwatch_log_group.postgresql.name
}
