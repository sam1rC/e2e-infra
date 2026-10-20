resource "aws_security_group" "this" {
  name_prefix = "${local.name}-"
  description = "Tareas ECS ${local.name}: entrada solo desde el ALB, salida solo a destinos declarados"
  vpc_id      = var.vpc_id

  # Sin reglas en línea; Terraform retira la salida abierta que AWS crea por defecto.

  tags = merge(var.tags, { Name = local.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  count = (var.alb_enabled != null ? var.alb_enabled : var.alb_security_group_id != null) ? 1 : 0

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  description                  = "Desde el ALB al puerto del contenedor"

  tags = merge(var.tags, { Name = "${local.name}-from-alb" })
}

# trivy:ignore:AWS-0104 Una salida a 0.0.0.0/0 solo existe si el consumidor la declara explícitamente en egress_rules (p. ej. HTTPS 443 por la NAT hacia la pasarela de pagos, allow_internet_egress de los blueprints, desactivado por defecto).
resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.egress_rules

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value.security_group_id
  prefix_list_id               = each.value.prefix_list_id
  cidr_ipv4                    = each.value.cidr_ipv4
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = each.value.description

  tags = merge(var.tags, { Name = "${local.name}-to-${each.key}" })
}
