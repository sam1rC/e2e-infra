resource "aws_security_group" "this" {
  name_prefix = "${local.name}-alb-"
  description = "ALB interno ${local.name}: sin entrada (la anade el modulo de edge) y salida solo hacia los targets"
  vpc_id      = var.vpc_id

  # Sin reglas en línea: la entrada la añade el módulo de edge y la salida son las reglas de abajo
  # (Terraform retira la salida abierta que AWS crea por defecto).

  tags = merge(var.tags, { Name = "${local.name}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

# Única salida del ALB: hacia los security groups de los targets, en el puerto de la app.
resource "aws_vpc_security_group_egress_rule" "to_targets" {
  for_each = var.egress_targets

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = "Hacia los targets ${each.key}"

  tags = merge(var.tags, { Name = "${local.name}-alb-to-${each.key}" })
}

resource "aws_lb" "this" {
  name               = local.name
  load_balancer_type = "application"
  internal           = true
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.this.id]

  drop_invalid_header_fields = true
  desync_mitigation_mode     = "strictest"
  enable_deletion_protection = var.environment == "prod"
  idle_timeout               = var.idle_timeout_seconds
  ip_address_type            = "ipv4"

  dynamic "access_logs" {
    for_each = var.access_logs_bucket_name == null ? [] : [var.access_logs_bucket_name]

    content {
      enabled = true
      bucket  = access_logs.value
      prefix  = var.access_logs_prefix
    }
  }

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name                 = "${var.project}-${var.environment}-${each.key}"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  port                 = each.value.port
  protocol             = each.value.protocol
  protocol_version     = each.value.protocol_version
  deregistration_delay = each.value.deregistration_delay

  health_check {
    enabled             = true
    path                = each.value.health_check.path
    port                = each.value.health_check.port
    protocol            = each.value.protocol
    matcher             = each.value.health_check.matcher
    interval            = each.value.health_check.interval
    timeout             = each.value.health_check.timeout
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-${each.key}" })
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Sin regla coincidente no se sirve nada: ni el DNS interno del ALB ni un Host ajeno llegan a la app.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "this" {
  for_each = var.listener_rules

  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group].arn
  }

  dynamic "condition" {
    for_each = length(each.value.host_headers) > 0 ? [each.value.host_headers] : []

    content {
      host_header {
        values = condition.value
      }
    }
  }

  dynamic "condition" {
    for_each = length(each.value.path_patterns) > 0 ? [each.value.path_patterns] : []

    content {
      path_pattern {
        values = condition.value
      }
    }
  }

  tags = var.tags
}
