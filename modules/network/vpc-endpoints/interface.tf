resource "aws_security_group" "interface" {
  name_prefix = "${local.name}-vpce-"
  description = "Endpoints de interfaz de ${local.name}: HTTPS solo desde los security groups de aplicacion"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${local.name}-vpce" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_app_security_groups" {
  for_each = var.allowed_security_group_ids

  security_group_id            = aws_security_group.interface.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS desde el security group ${each.key}"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "from_vpc_cidr" {
  count = var.vpc_cidr_fallback ? 1 : 0

  security_group_id = aws_security_group.interface.id
  cidr_ipv4         = var.vpc_cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS desde la VPC (fallback)"

  tags = var.tags
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_services)

  vpc_id              = var.vpc_id
  service_name        = "${local.service_prefix}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.interface.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${local.name}-${each.key}" })
}
