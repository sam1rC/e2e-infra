locals {
  # Las listas se publican ordenadas por az_names (StringList, separadas por comas).
  ssm_parameters = var.publish_ssm_parameters ? merge(
    {
      "vpc_id"   = aws_vpc.this.id
      "vpc_cidr" = aws_vpc.this.cidr_block
    },
    { for tier, subnets in local.subnet_ids_by_az : "subnet_ids/${tier}" => join(",", [for az in var.az_names : subnets[az]]) if length(subnets) > 0 },
    { for tier, tables in local.route_table_ids_by_tier : "route_table_ids/${tier}" => join(",", tables) if length(tables) > 0 },
  ) : {}
}

resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_parameters

  name  = "${local.ssm_prefix}/${each.key}"
  type  = contains(["vpc_id", "vpc_cidr"], each.key) ? "String" : "StringList"
  value = each.value

  tags = var.tags
}
