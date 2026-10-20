# Regla de entrada del ALB desde los VPC origins de CloudFront. El módulo cdn usa el provider de us-east-1:
# si la aplicación está en us-east-1 la crea él (mismas direcciones de estado que antes); si está en otra región,
# la crea esta capa con el provider de la región de la aplicación, donde AWS crea el SG
# CloudFront-VPCOrigins-Service-SG al crear el VPC origin.
locals {
  alb_in_us_east_1 = data.aws_region.current.region == "us-east-1"
}

data "aws_security_group" "cloudfront_vpc_origins" {
  count = local.alb_in_us_east_1 ? 0 : 1

  # Depende del VPC origin sin depends_on (que aplazaría la lectura en cada plan con cambios en el módulo):
  # mientras el origin no existe, vpc_id es desconocido y la lectura se hace en el apply.
  vpc_id = module.cdn.vpc_origin_id == null ? null : local.network["vpc_id"]

  filter {
    name   = "group-name"
    values = ["CloudFront-VPCOrigins-Service-SG"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  count = local.alb_in_us_east_1 ? 0 : 1

  security_group_id            = local.app["alb_security_group_id"]
  referenced_security_group_id = data.aws_security_group.cloudfront_vpc_origins[0].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS desde CloudFront VPC origins (SG gestionado por AWS)"

  tags = var.tags
}
