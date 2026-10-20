locals {
  name = "${var.project}-${var.environment}"

  az_index = { for i, az in var.az_names : az => i }
  first_az = var.az_names[0]

  # Desplazamientos fijos por capa: añadir una AZ al final no renumera las subredes existentes.
  tier_offset = { public = 0, app = 4, data = 8 }

  tiers_enabled = {
    for tier, enabled in var.subnet_tiers : tier => enabled
  }

  subnet_cidrs = {
    for tier, offset in local.tier_offset : tier => {
      for az, i in local.az_index : az => cidrsubnet(var.cidr_block, var.subnet_newbits, offset + i)
    }
  }

  # Claves estables (nombre de AZ) de cada capa activada
  public_azs = local.tiers_enabled.public ? local.az_index : {}
  app_azs    = local.tiers_enabled.app ? local.az_index : {}
  data_azs   = local.tiers_enabled.data ? local.az_index : {}

  nat_zonal_azs = (
    var.nat_mode == "zonal_single" ? { (local.first_az) = 0 } :
    var.nat_mode == "zonal_per_az" ? local.az_index :
    {}
  )

  # Gateway NAT que usa cada AZ de la capa app
  nat_gateway_by_az = {
    for az in keys(local.app_azs) : az => (
      var.nat_mode == "regional" ? aws_nat_gateway.regional[0].id :
      var.nat_mode == "zonal_single" ? aws_nat_gateway.zonal[local.first_az].id :
      aws_nat_gateway.zonal[az].id
    ) if var.nat_mode != "none"
  }

  nat_gateway_ids = merge(
    { for az, nat in aws_nat_gateway.zonal : az => nat.id },
    { for nat in aws_nat_gateway.regional : "regional" => nat.id },
  )

  flow_log_format = coalesce(
    try(var.flow_logs.log_format, null),
    join(" ", [for f in [
      "version", "account-id", "interface-id", "srcaddr", "dstaddr", "srcport", "dstport", "protocol",
      "packets", "bytes", "start", "end", "action", "log-status", "vpc-id", "subnet-id", "instance-id",
      "tcp-flags", "type", "pkt-srcaddr", "pkt-dstaddr", "region", "az-id", "sublocation-type",
      "sublocation-id", "pkt-src-aws-service", "pkt-dst-aws-service", "flow-direction", "traffic-path",
    ] : "$${${f}}"])
  )

  ssm_prefix = "/${var.project}/${var.environment}/network"
}
