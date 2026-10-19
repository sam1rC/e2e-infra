locals {
  subnet_ids_by_az = {
    public = { for az, s in aws_subnet.public : az => s.id }
    app    = { for az, s in aws_subnet.app : az => s.id }
    data   = { for az, s in aws_subnet.data : az => s.id }
  }

  route_table_ids_by_tier = {
    public = [for rt in aws_route_table.public : rt.id]
    app    = [for az in var.az_names : aws_route_table.app[az].id if contains(keys(aws_route_table.app), az)]
    data   = [for az in var.az_names : aws_route_table.data[az].id if contains(keys(aws_route_table.data), az)]
  }
}

output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR de la VPC."
  value       = aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "IDs de subred por capa (public, app, data), ordenados según az_names. Las capas desactivadas quedan vacías."
  value = {
    for tier, subnets in local.subnet_ids_by_az : tier => [for az in var.az_names : subnets[az] if contains(keys(subnets), az)]
  }
}

output "subnet_ids_by_az" {
  description = "IDs de subred por capa y nombre de AZ."
  value       = local.subnet_ids_by_az
}

output "subnet_cidr_blocks" {
  description = "CIDR de cada subred, por capa y nombre de AZ (solo capas activadas)."
  value = {
    public = { for az in keys(local.public_azs) : az => local.subnet_cidrs["public"][az] }
    app    = { for az in keys(local.app_azs) : az => local.subnet_cidrs["app"][az] }
    data   = { for az in keys(local.data_azs) : az => local.subnet_cidrs["data"][az] }
  }
}

output "route_table_ids" {
  description = "IDs de tablas de rutas por capa (public: una; app y data: una por AZ en el orden de az_names)."
  value       = local.route_table_ids_by_tier
}

output "nat_gateway_ids" {
  description = "IDs de NAT por clave: nombre de AZ (zonales) o 'regional'."
  value       = local.nat_gateway_ids
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway (null si no se crea)."
  value       = one(aws_internet_gateway.this[*].id)
}

output "availability_zones" {
  description = "Zonas de disponibilidad usadas, en el orden recibido."
  value       = var.az_names
}
