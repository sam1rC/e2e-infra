output "service_name" {
  description = "Nombre del servicio ECS."
  value       = local.name
}

output "service_id" {
  description = "ARN del servicio ECS."
  value       = one(concat(aws_ecs_service.managed[*].id, aws_ecs_service.external[*].id))
}

output "task_definition_arn" {
  description = "ARN de la task definition gestionada por OpenTofu (con app_deploys_outside_iac, el pipeline de la aplicación registra revisiones nuevas)."
  value       = aws_ecs_task_definition.this.arn
}

output "security_group_id" {
  description = "Security group de las tareas. Añádelo a los orígenes permitidos de los endpoints de VPC y de las bases de datos, y como egress_targets de alb-internal."
  value       = aws_security_group.this.id
}

output "execution_role_arn" {
  description = "ARN del execution role (descarga de imagen, logs y secretos declarados)."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN del task role (identidad de la aplicación; vacío salvo los permisos inyectados)."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Nombre del task role, para adjuntar políticas desde fuera del módulo."
  value       = aws_iam_role.task.name
}

output "log_group_name" {
  description = "Nombre del log group del servicio."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN del log group del servicio."
  value       = aws_cloudwatch_log_group.this.arn
}

output "autoscaling_resource_id" {
  description = "resource_id del Application Auto Scaling del servicio (para políticas adicionales)."
  value       = aws_appautoscaling_target.this.resource_id
}
