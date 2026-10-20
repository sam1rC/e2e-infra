# NACL de la capa data (sin estado): solo admite las subredes app en los puertos de datos, el tráfico
# interno de la capa (réplicas, TCP en puertos altos: los de datos y las respuestas) y las respuestas
# efímeras hacia app. Sin ICMP ni UDP: ninguna regla admite todos los protocolos. Las NACL de las demás capas se dejan
# por defecto: son difíciles de mantener y los security groups ya acotan el tráfico.
locals {
  nacl_enabled = local.tiers_enabled.app && local.tiers_enabled.data

  nacl_app_ingress = local.nacl_enabled ? {
    for pair in setproduct(keys(local.az_index), range(length(var.data_tier_ports))) :
    "${pair[0]}-${var.data_tier_ports[pair[1]]}" => {
      cidr        = local.subnet_cidrs["app"][pair[0]]
      port        = var.data_tier_ports[pair[1]]
      rule_number = 100 + 10 * local.az_index[pair[0]] + pair[1]
    }
  } : {}

  nacl_app_egress = local.nacl_enabled ? {
    for az, i in local.az_index : az => {
      cidr        = local.subnet_cidrs["app"][az]
      rule_number = 100 + i
    }
  } : {}

  nacl_data_internal = local.nacl_enabled ? {
    for az, i in local.az_index : az => {
      cidr        = local.subnet_cidrs["data"][az]
      rule_number = 200 + i
    }
  } : {}
}

resource "aws_network_acl" "data" {
  count = local.nacl_enabled ? 1 : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.data : s.id]

  tags = merge(var.tags, { Name = "${local.name}-data", Tier = "data" })
}

resource "aws_network_acl_rule" "data_ingress_from_app" {
  for_each = local.nacl_app_ingress

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = each.value.rule_number
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "data_egress_to_app" {
  for_each = local.nacl_app_egress

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = each.value.rule_number
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "data_ingress_internal" {
  for_each = local.nacl_data_internal

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = each.value.rule_number
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "data_egress_internal" {
  for_each = local.nacl_data_internal

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = each.value.rule_number
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 1024
  to_port        = 65535
}
