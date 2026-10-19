resource "aws_cloudfront_vpc_origin" "this" {
  vpc_origin_endpoint_config {
    name                   = "${local.name}-alb"
    arn                    = var.alb_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "https-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  tags = var.tags
}

resource "aws_cloudfront_distribution" "this" {
  comment             = "${local.name}: aplicación/API detrás de WAF con origen privado"
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.price_class
  aliases             = var.domain_names
  web_acl_id          = var.web_acl_arn
  wait_for_deployment = true

  origin {
    origin_id   = local.origin_id
    domain_name = var.alb_dns_name

    vpc_origin_config {
      vpc_origin_id            = aws_cloudfront_vpc_origin.this.id
      origin_read_timeout      = var.origin_read_timeout_seconds
      origin_keepalive_timeout = 5
    }
  }

  # Aplicación y API: sin caché y con todas las cabeceras del visitante (incluido Host: ADR 0007).
  default_cache_behavior {
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer.id
    response_headers_policy_id = var.response_headers_policy_id
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.static_path_patterns

    content {
      path_pattern               = ordered_cache_behavior.value
      target_origin_id           = local.origin_id
      viewer_protocol_policy     = "redirect-to-https"
      allowed_methods            = ["GET", "HEAD", "OPTIONS"]
      cached_methods             = ["GET", "HEAD"]
      compress                   = true
      cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer.id
      response_headers_policy_id = var.response_headers_policy_id
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(var.tags, { Name = local.name })
}
