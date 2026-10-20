mock_provider "aws" {
  mock_resource "aws_cloudfront_vpc_origin" {
    defaults = {
      id = "vo_0123456789abcdef"
    }
  }

  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn            = "arn:aws:cloudfront::123456789012:distribution/E1ABCDEFGHIJKL"
      domain_name    = "d111111abcdef8.cloudfront.net"
      hosted_zone_id = "Z2FDTNDATAQYW2"
    }
  }

  mock_resource "aws_cloudwatch_log_delivery_destination" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:delivery-destination:mock"
    }
  }
}

variables {
  project                    = "acme"
  environment                = "prod"
  vpc_id                     = "vpc-0123456789abcdef0"
  alb_arn                    = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/acme-prod/50dc6c495c0c9188"
  alb_dns_name               = "internal-acme-prod-123456.us-east-1.elb.amazonaws.com"
  alb_security_group_id      = "sg-0aaaaaaaaaaaaaaaa"
  domain_names               = ["app.example.com"]
  acm_certificate_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  response_headers_policy_id = "rhp-security-headers"
}

run "vpc_origin_uses_https_only_tls12" {
  command = plan

  assert {
    condition = alltrue([
      for c in aws_cloudfront_vpc_origin.this.vpc_origin_endpoint_config :
      c.origin_protocol_policy == "https-only" &&
      c.arn == "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/acme-prod/50dc6c495c0c9188" &&
      c.https_port == 443 &&
      alltrue([for p in c.origin_ssl_protocols : toset(p.items) == toset(["TLSv1.2"]) && p.quantity == 1])
    ])
    error_message = "El VPC origin debe ser https-only, TLSv1.2 y apuntar al ALB."
  }
}

run "viewer_side_is_tls12_2021_http3_and_aliased" {
  command = plan

  assert {
    condition = (
      aws_cloudfront_distribution.this.http_version == "http2and3" &&
      aws_cloudfront_distribution.this.is_ipv6_enabled &&
      aws_cloudfront_distribution.this.price_class == "PriceClass_100" &&
      toset(aws_cloudfront_distribution.this.aliases) == toset(["app.example.com"])
    )
    error_message = "HTTP/2+3, IPv6, price class por defecto y alias del dominio."
  }

  assert {
    condition = alltrue([
      for v in aws_cloudfront_distribution.this.viewer_certificate :
      v.minimum_protocol_version == "TLSv1.2_2021" && v.ssl_support_method == "sni-only" && v.acm_certificate_arn == var.acm_certificate_arn
    ])
    error_message = "Certificado ACM con TLSv1.2_2021 y SNI."
  }
}

run "default_behavior_is_uncached_all_viewer_and_https_redirect" {
  command = plan

  assert {
    condition = alltrue([
      for b in aws_cloudfront_distribution.this.default_cache_behavior :
      b.viewer_protocol_policy == "redirect-to-https" &&
      b.cache_policy_id == data.aws_cloudfront_cache_policy.caching_disabled.id &&
      b.origin_request_policy_id == data.aws_cloudfront_origin_request_policy.all_viewer.id &&
      b.response_headers_policy_id == "rhp-security-headers" &&
      length(b.allowed_methods) == 7
    ])
    error_message = "Por defecto: sin caché, AllViewer (reenvía Host), redirect a HTTPS, cabeceras de seguridad y todos los métodos."
  }

  assert {
    condition = (
      data.aws_cloudfront_cache_policy.caching_disabled.name == "Managed-CachingDisabled" &&
      data.aws_cloudfront_origin_request_policy.all_viewer.name == "Managed-AllViewer"
    )
    error_message = "Deben usarse las políticas gestionadas CachingDisabled y AllViewer (no AllViewerExceptHostHeader: ADR 0007)."
  }
}

run "static_paths_are_cached_with_get_only" {
  command = plan

  assert {
    condition = (
      length(aws_cloudfront_distribution.this.ordered_cache_behavior) == 2 &&
      toset([for b in aws_cloudfront_distribution.this.ordered_cache_behavior : b.path_pattern]) == toset(["/static/*", "/assets/*"]) &&
      alltrue([
        for b in aws_cloudfront_distribution.this.ordered_cache_behavior :
        b.cache_policy_id == data.aws_cloudfront_cache_policy.caching_optimized.id && b.compress && toset(b.allowed_methods) == toset(["GET", "HEAD", "OPTIONS"]) && b.viewer_protocol_policy == "redirect-to-https"
      ])
    )
    error_message = "/static/* y /assets/* usan CachingOptimized, compresión y solo métodos de lectura."
  }

  assert {
    condition     = data.aws_cloudfront_cache_policy.caching_optimized.name == "Managed-CachingOptimized"
    error_message = "Los estáticos usan la política gestionada CachingOptimized."
  }
}

run "static_paths_are_configurable" {
  command = plan

  variables {
    static_path_patterns = ["/public/*"]
  }

  assert {
    condition     = length(aws_cloudfront_distribution.this.ordered_cache_behavior) == 1
    error_message = "Los patrones estáticos salen de static_path_patterns."
  }
}

run "web_acl_is_attached_when_given" {
  command = plan

  variables {
    web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/acme/11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = aws_cloudfront_distribution.this.web_acl_id == var.web_acl_arn
    error_message = "El Web ACL debe asociarse a la distribución."
  }
}

run "alb_ingress_from_cloudfront_managed_sg_by_default" {
  command = plan

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.alb_from_cloudfront_sg) == 1 &&
      length(aws_vpc_security_group_ingress_rule.alb_from_cloudfront_prefix_list) == 0 &&
      aws_vpc_security_group_ingress_rule.alb_from_cloudfront_sg[0].security_group_id == "sg-0aaaaaaaaaaaaaaaa" &&
      aws_vpc_security_group_ingress_rule.alb_from_cloudfront_sg[0].from_port == 443 &&
      aws_vpc_security_group_ingress_rule.alb_from_cloudfront_sg[0].to_port == 443 &&
      aws_vpc_security_group_ingress_rule.alb_from_cloudfront_sg[0].cidr_ipv4 == null
    )
    error_message = "Por defecto el ALB admite 443 solo desde el SG gestionado de CloudFront, sin CIDR."
  }
}

run "alb_ingress_prefix_list_fallback" {
  command = plan

  variables {
    alb_ingress_source = "cloudfront_prefix_list"
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.alb_from_cloudfront_sg) == 0 &&
      length(aws_vpc_security_group_ingress_rule.alb_from_cloudfront_prefix_list) == 1 &&
      length(data.aws_security_group.cloudfront_vpc_origins) == 0
    )
    error_message = "El respaldo usa la prefix list origin-facing y no busca el SG gestionado."
  }
}

run "dns_alias_records_per_domain_and_type" {
  command = plan

  variables {
    domain_names = ["app.example.com", "www.example.com"]
    zone_id      = "Z0123456789ABCDEFGHIJ"
  }

  assert {
    condition = toset(keys(aws_route53_record.alias)) == toset([
      "app.example.com-A", "app.example.com-AAAA", "www.example.com-A", "www.example.com-AAAA",
    ])
    error_message = "Un registro A y AAAA por dominio, con clave estable."
  }
}

run "no_dns_records_without_zone" {
  command = plan

  assert {
    condition     = length(aws_route53_record.alias) == 0
    error_message = "Sin zone_id el DNS se gestiona fuera."
  }
}

run "no_access_logs_by_default" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_delivery.this) == 0 && length(aws_cloudwatch_log_delivery_source.this) == 0
    error_message = "Sin bucket de logs no se crea la entrega."
  }
}

run "access_logs_delivered_to_s3_without_acls" {
  command = plan

  variables {
    log_bucket_arn = "arn:aws:s3:::acme-prod-logs-123456789012"
  }

  assert {
    condition = (
      length(aws_cloudwatch_log_delivery.this) == 1 &&
      aws_cloudwatch_log_delivery_source.this[0].log_type == "ACCESS_LOGS" &&
      alltrue([for d in aws_cloudwatch_log_delivery_destination.this[0].delivery_destination_configuration : d.destination_resource_arn == "arn:aws:s3:::acme-prod-logs-123456789012"])
    )
    error_message = "Con bucket de logs se crean origen, destino y entrega (logging v2)."
  }
}

run "rejects_certificate_outside_us_east_1" {
  command = plan

  variables {
    acm_certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  }

  expect_failures = [var.acm_certificate_arn]
}

run "rejects_regional_web_acl" {
  command = plan

  variables {
    web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/acme/11111111-2222-3333-4444-555555555555"
  }

  expect_failures = [var.web_acl_arn]
}

run "rejects_non_alb_arn" {
  command = plan

  variables {
    alb_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/acme/abc"
  }

  expect_failures = [var.alb_arn]
}

run "rejects_unknown_ingress_source" {
  command = plan

  variables {
    alb_ingress_source = "anywhere"
  }

  expect_failures = [var.alb_ingress_source]
}

run "rejects_origin_timeout_above_default_quota" {
  command = plan

  variables {
    origin_read_timeout_seconds = 120
  }

  expect_failures = [var.origin_read_timeout_seconds]
}

run "rejects_missing_domain" {
  command = plan

  variables {
    domain_names = []
  }

  expect_failures = [var.domain_names]
}

run "access_logs_flag_overrides_null_check" {
  command = plan

  variables {
    log_bucket_arn      = "arn:aws:s3:::acme-prod-logs-123456789012"
    access_logs_enabled = false
  }

  assert {
    condition     = length(aws_cloudwatch_log_delivery_source.this) == 0 && length(aws_cloudwatch_log_delivery.this) == 0
    error_message = "access_logs_enabled = false desactiva los logs aunque haya bucket."
  }
}

run "rejects_access_logs_without_bucket" {
  command = plan

  variables {
    log_bucket_arn      = null
    access_logs_enabled = true
  }

  expect_failures = [var.access_logs_enabled]
}

run "alb_ingress_none_leaves_the_rule_to_the_caller" {
  command = plan

  variables {
    alb_ingress_source = "none"
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.alb_from_cloudfront_sg) == 0 &&
      length(aws_vpc_security_group_ingress_rule.alb_from_cloudfront_prefix_list) == 0 &&
      length(data.aws_security_group.cloudfront_vpc_origins) == 0
    )
    error_message = "Con alb_ingress_source = none el módulo no crea reglas en el SG del ALB."
  }
}
