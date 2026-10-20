data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Cuenta de ELB que entrega los logs de acceso del ALB en la región (las regiones abiertas desde 2022 usan
# el principal de servicio logdelivery.elasticloadbalancing.amazonaws.com).
data "aws_elb_service_account" "current" {}
