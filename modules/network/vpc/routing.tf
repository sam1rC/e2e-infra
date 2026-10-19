resource "aws_route_table" "public" {
  count = local.tiers_enabled.public ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${local.name}-public", Tier = "public" })
}

resource "aws_route" "public_default" {
  count = local.tiers_enabled.public ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  for_each = local.public_azs

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[0].id
}

# Una tabla por AZ: con zonal_per_az cada AZ sale por su NAT; en los demás modos todas apuntan a la misma.
resource "aws_route_table" "app" {
  for_each = local.app_azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${local.name}-app-${each.key}", Tier = "app" })
}

resource "aws_route" "app_default" {
  for_each = local.nat_gateway_by_az

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = each.value
}

resource "aws_route_table_association" "app" {
  for_each = local.app_azs

  subnet_id      = aws_subnet.app[each.key].id
  route_table_id = aws_route_table.app[each.key].id
}

# La capa data no recibe ninguna ruta por defecto: solo la local y los endpoints de tipo gateway.
resource "aws_route_table" "data" {
  for_each = local.data_azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${local.name}-data-${each.key}", Tier = "data" })
}

resource "aws_route_table_association" "data" {
  for_each = local.data_azs

  subnet_id      = aws_subnet.data[each.key].id
  route_table_id = aws_route_table.data[each.key].id
}
