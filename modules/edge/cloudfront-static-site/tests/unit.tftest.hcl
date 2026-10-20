mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
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
  domain_names               = ["www.example.com"]
  acm_certificate_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  response_headers_policy_id = "rhp-security-headers"
}

run "oac_signs_every_request_with_sigv4" {
  command = plan

  assert {
    condition = (
      aws_cloudfront_origin_access_control.this.origin_access_control_origin_type == "s3" &&
      aws_cloudfront_origin_access_control.this.signing_behavior == "always" &&
      aws_cloudfront_origin_access_control.this.signing_protocol == "sigv4"
    )
    error_message = "El OAC debe firmar siempre con SigV4."
  }
}

run "bucket_policy_grants_read_only_to_this_distribution" {
  command = plan

  assert {
    condition = (
      toset(output.cloudfront_read_policy_statement.actions) == toset(["s3:GetObject"]) &&
      toset(output.cloudfront_read_policy_statement.principals[0].identifiers) == toset(["cloudfront.amazonaws.com"]) &&
      output.cloudfront_read_policy_statement.conditions[0].variable == "AWS:SourceArn"
    )
    error_message = "Solo cloudfront.amazonaws.com puede hacer s3:GetObject, condicionado a AWS:SourceArn."
  }
}

run "bucket_policy_pins_the_exact_distribution_arn" {
  command = apply

  assert {
    condition     = toset(output.cloudfront_read_policy_statement.conditions[0].values) == toset([aws_cloudfront_distribution.this.arn])
    error_message = "La condición debe fijar el ARN exacto de la distribución."
  }
}

run "own_kms_key_created_by_default" {
  command = plan

  assert {
    condition     = length(module.kms) == 1
    error_message = "Sin kms_key_arn el módulo crea su propia CMK."
  }
}

run "external_kms_key_is_used_when_given" {
  command = apply

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/99999999-8888-7777-6666-555555555555"
  }

  assert {
    condition     = length(module.kms) == 0 && output.kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/99999999-8888-7777-6666-555555555555"
    error_message = "Con kms_key_arn no se crea clave y se usa la indicada."
  }
}

run "default_behavior_serves_s3_with_caching_and_read_only_methods" {
  command = plan

  assert {
    condition = alltrue([
      for b in aws_cloudfront_distribution.this.default_cache_behavior :
      b.viewer_protocol_policy == "redirect-to-https" &&
      toset(b.allowed_methods) == toset(["GET", "HEAD", "OPTIONS"]) &&
      b.compress &&
      b.cache_policy_id == data.aws_cloudfront_cache_policy.caching_optimized.id &&
      b.response_headers_policy_id == "rhp-security-headers"
    ])
    error_message = "El sitio estático usa CachingOptimized, solo lectura, compresión y cabeceras de seguridad."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.default_root_object == "index.html"
    error_message = "El objeto raíz debe ser index.html."
  }
}

run "viewer_tls12_2021_http3" {
  command = plan

  assert {
    condition = alltrue([
      for v in aws_cloudfront_distribution.this.viewer_certificate :
      v.minimum_protocol_version == "TLSv1.2_2021" && v.ssl_support_method == "sni-only"
    ]) && aws_cloudfront_distribution.this.http_version == "http2and3"
    error_message = "TLSv1.2_2021, SNI y HTTP/2+3."
  }
}

run "spa_errors_rewritten_to_index_by_default" {
  command = plan

  assert {
    condition = (
      toset([for e in aws_cloudfront_distribution.this.custom_error_response : e.error_code]) == toset([403, 404]) &&
      alltrue([for e in aws_cloudfront_distribution.this.custom_error_response : e.response_code == 200 && e.response_page_path == "/index.html"])
    )
    error_message = "403 y 404 se sirven como /index.html con 200 (SPA)."
  }
}

run "spa_rewrite_can_be_disabled" {
  command = plan

  variables {
    spa_error_codes = []
  }

  assert {
    condition     = length(aws_cloudfront_distribution.this.custom_error_response) == 0
    error_message = "Con spa_error_codes vacío no se reescriben errores."
  }
}

run "no_api_origin_by_default" {
  command = plan

  assert {
    condition     = length(aws_cloudfront_distribution.this.origin) == 1 && length(aws_cloudfront_distribution.this.ordered_cache_behavior) == 0
    error_message = "Sin api solo existe el origen S3."
  }
}

run "api_origin_is_https_only_uncached_and_without_host_forwarding" {
  command = plan

  variables {
    api = { domain_name = "abc123.execute-api.us-east-1.amazonaws.com" }
  }

  assert {
    condition = (
      length(aws_cloudfront_distribution.this.origin) == 2 &&
      anytrue([
        for o in aws_cloudfront_distribution.this.origin :
        o.domain_name == "abc123.execute-api.us-east-1.amazonaws.com" &&
        alltrue([for c in o.custom_origin_config : c.origin_protocol_policy == "https-only" && toset(c.origin_ssl_protocols) == toset(["TLSv1.2"])])
      ])
    )
    error_message = "El origen de API es https-only con TLSv1.2."
  }

  assert {
    condition = alltrue([
      for b in aws_cloudfront_distribution.this.ordered_cache_behavior :
      b.path_pattern == "/api/*" &&
      b.cache_policy_id == data.aws_cloudfront_cache_policy.caching_disabled.id &&
      b.origin_request_policy_id == data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id &&
      length(b.allowed_methods) == 7
    ])
    error_message = "/api/* va sin caché, con AllViewerExceptHostHeader y todos los métodos."
  }

  assert {
    condition = (
      data.aws_cloudfront_cache_policy.caching_disabled.name == "Managed-CachingDisabled" &&
      data.aws_cloudfront_origin_request_policy.all_viewer_except_host.name == "Managed-AllViewerExceptHostHeader"
    )
    error_message = "Se usan las políticas gestionadas por nombre."
  }
}

run "origin_verify_header_only_when_secret_given" {
  command = plan

  variables {
    api = { domain_name = "abc123.execute-api.us-east-1.amazonaws.com" }
  }

  assert {
    condition     = alltrue([for o in aws_cloudfront_distribution.this.origin : length(o.custom_header) == 0])
    error_message = "Sin secreto no se añade ninguna cabecera."
  }
}

run "origin_verify_header_added_with_secret" {
  command = plan

  variables {
    api                      = { domain_name = "abc123.execute-api.us-east-1.amazonaws.com" }
    api_origin_verify_secret = "0123456789abcdef0123456789abcdef"
  }

  assert {
    condition = anytrue([
      for o in aws_cloudfront_distribution.this.origin :
      anytrue([for h in o.custom_header : h.name == "x-origin-verify"])
    ])
    error_message = "El origen de API debe enviar x-origin-verify."
  }
}

run "api_path_pattern_is_configurable" {
  command = plan

  variables {
    api = { domain_name = "abc123.execute-api.us-east-1.amazonaws.com", path_pattern = "/v1/*" }
  }

  assert {
    condition     = alltrue([for b in aws_cloudfront_distribution.this.ordered_cache_behavior : b.path_pattern == "/v1/*"])
    error_message = "El patrón de la API sale de api.path_pattern."
  }
}

run "dns_alias_records_when_zone_given" {
  command = plan

  variables {
    zone_id = "Z0123456789ABCDEFGHIJ"
  }

  assert {
    condition     = toset(keys(aws_route53_record.alias)) == toset(["www.example.com-A", "www.example.com-AAAA"])
    error_message = "Un registro A y AAAA por dominio."
  }
}

run "access_logs_optional" {
  command = plan

  variables {
    log_bucket_arn = "arn:aws:s3:::acme-prod-logs-123456789012"
  }

  assert {
    condition     = length(aws_cloudwatch_log_delivery.this) == 1
    error_message = "Con bucket de logs se crea la entrega v2."
  }
}

run "rejects_secret_without_api" {
  command = plan

  variables {
    api_origin_verify_secret = "0123456789abcdef0123456789abcdef"
  }

  expect_failures = [var.api_origin_verify_secret]
}

run "rejects_short_secret" {
  command = plan

  variables {
    api                      = { domain_name = "abc123.execute-api.us-east-1.amazonaws.com" }
    api_origin_verify_secret = "corto"
  }

  expect_failures = [var.api_origin_verify_secret]
}

run "rejects_api_domain_with_scheme" {
  command = plan

  variables {
    api = { domain_name = "https://abc123.execute-api.us-east-1.amazonaws.com" }
  }

  expect_failures = [var.api]
}

run "rejects_certificate_outside_us_east_1" {
  command = plan

  variables {
    acm_certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  }

  expect_failures = [var.acm_certificate_arn]
}

run "rejects_kms_alias_instead_of_arn" {
  command = plan

  variables {
    kms_key_arn = "alias/acme-prod-static-site"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_unrewritable_spa_error_code" {
  command = plan

  variables {
    spa_error_codes = [200]
  }

  expect_failures = [var.spa_error_codes]
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
