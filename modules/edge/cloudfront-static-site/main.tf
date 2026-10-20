resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${local.name}-s3"
  description                       = "OAC del bucket estático de ${local.name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  comment             = "${local.name}: sitio estático"
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.price_class
  aliases             = var.domain_names
  default_root_object = "index.html"
  web_acl_id          = var.web_acl_arn
  wait_for_deployment = true

  origin {
    origin_id                = local.s3_origin_id
    domain_name              = module.bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  dynamic "origin" {
    for_each = var.api == null ? [] : [var.api]

    content {
      origin_id   = local.api_origin_id
      domain_name = origin.value.domain_name
      origin_path = origin.value.origin_path

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      dynamic "custom_header" {
        for_each = var.api_origin_verify_secret == null ? [] : [1]

        content {
          name  = "x-origin-verify"
          value = var.api_origin_verify_secret
        }
      }
    }
  }

  default_cache_behavior {
    target_origin_id           = local.s3_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = var.response_headers_policy_id
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.api == null ? [] : [var.api]

    content {
      path_pattern               = ordered_cache_behavior.value.path_pattern
      target_origin_id           = local.api_origin_id
      viewer_protocol_policy     = "redirect-to-https"
      allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods             = ["GET", "HEAD"]
      compress                   = true
      cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
      origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
      response_headers_policy_id = var.response_headers_policy_id
    }
  }

  dynamic "custom_error_response" {
    for_each = toset(var.spa_error_codes)

    content {
      error_code            = custom_error_response.value
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
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

resource "aws_route53_record" "alias" {
  for_each = local.dns_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
