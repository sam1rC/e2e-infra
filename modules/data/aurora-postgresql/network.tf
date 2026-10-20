resource "aws_security_group" "this" {
  name_prefix = "${local.name}-"
  description = "Aurora ${local.name}: entrada solo desde los SG autorizados, sin salida"
  vpc_id      = var.vpc_id

  # Sin reglas en línea ni de salida: la base de datos no inicia conexiones.
  # Terraform retira la salida abierta que AWS crea por defecto.

  tags = merge(var.tags, { Name = local.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_allowed" {
  for_each = var.allowed_security_group_ids

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = var.port
  to_port                      = var.port
  description                  = "PostgreSQL desde ${each.key}"

  tags = merge(var.tags, { Name = "${local.name}-from-${each.key}" })
}
