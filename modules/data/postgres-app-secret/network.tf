resource "aws_security_group" "rotation" {
  count = local.rotation_enabled ? 1 : 0

  name_prefix = "${var.name}-rotation-"
  description = "Funcion de rotacion de ${var.name}: salida solo a la base de datos y a Secrets Manager"
  vpc_id      = var.vpc_id

  # Sin reglas en línea; Terraform retira la salida abierta que AWS crea por defecto.

  tags = merge(var.tags, { Name = "${var.name}-rotation" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "rotation_to_db" {
  count = local.rotation_enabled ? 1 : 0

  security_group_id            = aws_security_group.rotation[0].id
  referenced_security_group_id = var.db_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  description                  = "Hacia PostgreSQL"

  tags = merge(var.tags, { Name = "${var.name}-rotation-to-db" })
}

resource "aws_vpc_security_group_egress_rule" "rotation_to_secretsmanager" {
  count = local.rotation_enabled ? 1 : 0

  security_group_id            = aws_security_group.rotation[0].id
  referenced_security_group_id = var.rotation.endpoint_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Hacia el endpoint de Secrets Manager"

  tags = merge(var.tags, { Name = "${var.name}-rotation-to-secretsmanager" })
}

resource "aws_vpc_security_group_ingress_rule" "db_from_rotation" {
  count = local.rotation_enabled ? 1 : 0

  security_group_id            = var.db_security_group_id
  referenced_security_group_id = aws_security_group.rotation[0].id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  description                  = "Desde la funcion de rotacion de secretos"

  tags = merge(var.tags, { Name = "${var.name}-db-from-rotation" })
}
