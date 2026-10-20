resource "aws_eip" "nat" {
  for_each = local.nat_zonal_azs

  domain = "vpc"

  tags = merge(var.tags, { Name = "${local.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "zonal" {
  for_each = local.nat_zonal_azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, { Name = "${local.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

# NAT regional en modo automático: sin subredes públicas ni EIP explícitas; AWS amplía la cobertura a las AZ
# con ENI y asigna las EIP. En modo manual, añadir o quitar availability_zone_address recrea la NAT.
resource "aws_nat_gateway" "regional" {
  count = var.nat_mode == "regional" ? 1 : 0

  vpc_id            = aws_vpc.this.id
  availability_mode = "regional"

  tags = merge(var.tags, { Name = "${local.name}-nat-regional" })

  depends_on = [aws_internet_gateway.this]
}

# El NAT regional escala de forma reactiva: ErrorPortAllocation > 0 indica agotamiento de puertos
# y es la señal para pasar a zonal_per_az.
resource "aws_cloudwatch_metric_alarm" "nat_port_allocation" {
  for_each = local.nat_gateway_ids

  alarm_name          = "${local.name}-nat-${each.key}-error-port-allocation"
  alarm_description   = "La NAT no pudo asignar puertos de origen (ErrorPortAllocation > 0)."
  namespace           = "AWS/NATGateway"
  metric_name         = "ErrorPortAllocation"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions

  dimensions = {
    NatGatewayId = each.value
  }

  tags = var.tags
}
