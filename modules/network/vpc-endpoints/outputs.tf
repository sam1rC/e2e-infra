output "security_group_id" {
  description = "ID del security group de los endpoints de interfaz."
  value       = aws_security_group.interface.id
}

output "interface_endpoint_ids" {
  description = "IDs de los endpoints de interfaz, por servicio."
  value       = { for k, e in aws_vpc_endpoint.interface : k => e.id }
}

output "gateway_endpoint_ids" {
  description = "IDs de los endpoints gateway, por servicio."
  value       = { for k, e in aws_vpc_endpoint.gateway : k => e.id }
}

output "gateway_endpoint_prefix_list_ids" {
  description = "ID de la lista de prefijos de cada endpoint gateway, por servicio: úsala como destino en las reglas de salida de los security groups (p. ej. egress_rules de ecs-service hacia S3)."
  value       = { for k, e in aws_vpc_endpoint.gateway : k => e.prefix_list_id }
}
