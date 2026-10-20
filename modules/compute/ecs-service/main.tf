resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn

  tags = var.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions    = jsonencode(local.container_definitions)

  # Con app_deploys_outside_iac el servicio puede seguir usando una revisión que OpenTofu ya no gestiona:
  # no se desregistra al reemplazarla.
  skip_destroy = var.app_deploys_outside_iac

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  # Rutas escribibles sobre un sistema de archivos raíz de solo lectura: volúmenes efímeros de la tarea.
  dynamic "volume" {
    for_each = local.writable_volumes

    content {
      name                = volume.key
      configure_at_launch = false
    }
  }

  tags = merge(var.tags, { Name = local.name })
}

# Dos recursos de servicio porque `lifecycle.ignore_changes` no admite condiciones: con
# app_deploys_outside_iac el pipeline de la aplicación actualiza la task definition y OpenTofu no la revierte.
# Ambos ignoran desired_count (lo gobierna el autoscaling). Mantén sus argumentos idénticos.
resource "aws_ecs_service" "managed" {
  count = var.app_deploys_outside_iac ? 0 : 1

  name            = local.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = local.desired_count

  deployment_minimum_healthy_percent = local.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = local.has_alb ? var.health_check_grace_period_seconds : null
  enable_execute_command             = var.enable_exec
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = local.has_alb ? [var.target_group_arn] : []

    content {
      target_group_arn = load_balancer.value
      container_name   = local.container_name
      container_port   = var.container_port
    }
  }

  tags = merge(var.tags, { Name = local.name })

  # capacity_provider_strategy: el servicio usa la estrategia por defecto del cluster y AWS la devuelve en el
  # servicio; sin ignorarla, cualquier actualización exige force_new_deployment (sandbox, 2026-10-14).
  lifecycle {
    ignore_changes = [desired_count, capacity_provider_strategy]
  }
}

resource "aws_ecs_service" "external" {
  count = var.app_deploys_outside_iac ? 1 : 0

  name            = local.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = local.desired_count

  deployment_minimum_healthy_percent = local.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = local.has_alb ? var.health_check_grace_period_seconds : null
  enable_execute_command             = var.enable_exec
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = local.has_alb ? [var.target_group_arn] : []

    content {
      target_group_arn = load_balancer.value
      container_name   = local.container_name
      container_port   = var.container_port
    }
  }

  tags = merge(var.tags, { Name = local.name })

  lifecycle {
    ignore_changes = [desired_count, task_definition, capacity_provider_strategy]
  }
}

resource "aws_appautoscaling_target" "this" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${local.cluster_name}/${local.name}"
  min_capacity       = local.min_tasks
  max_capacity       = var.max_tasks

  tags = var.tags

  depends_on = [aws_ecs_service.managed, aws_ecs_service.external]
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  resource_id        = aws_appautoscaling_target.this.resource_id

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_percent
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "requests" {
  count = var.requests_per_target == null ? 0 : 1

  name               = "${local.name}-requests"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  resource_id        = aws_appautoscaling_target.this.resource_id

  target_tracking_scaling_policy_configuration {
    target_value       = var.requests_per_target
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${var.alb_arn_suffix}/${var.target_group_arn_suffix}"
    }
  }
}
