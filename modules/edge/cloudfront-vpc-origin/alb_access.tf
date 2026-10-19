# Security group que AWS crea al crear el VPC origin. No se edita ni se crea ninguno con ese prefijo.
data "aws_security_group" "cloudfront_vpc_origins" {
  count = var.alb_ingress_source == "cloudfront_managed_sg" ? 1 : 0

  vpc_id = var.vpc_id

  filter {
    name   = "group-name"
    values = ["CloudFront-VPCOrigins-Service-SG"]
  }

  # El SG aparece después de crear el VPC origin.
  depends_on = [aws_cloudfront_vpc_origin.this]
}

data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  count = var.alb_ingress_source == "cloudfront_prefix_list" ? 1 : 0

  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront_sg" {
  count = var.alb_ingress_source == "cloudfront_managed_sg" ? 1 : 0

  security_group_id            = var.alb_security_group_id
  referenced_security_group_id = data.aws_security_group.cloudfront_vpc_origins[0].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS desde CloudFront VPC origins (SG gestionado por AWS)"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront_prefix_list" {
  count = var.alb_ingress_source == "cloudfront_prefix_list" ? 1 : 0

  security_group_id = var.alb_security_group_id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing[0].id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS desde CloudFront (prefix list origin-facing)"

  tags = var.tags
}
