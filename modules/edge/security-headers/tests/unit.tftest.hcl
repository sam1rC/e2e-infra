mock_provider "aws" {}

variables {
  project     = "acme"
  environment = "dev"
}

run "hsts_two_years_preload_and_subdomains" {
  command = plan

  assert {
    condition = alltrue([
      for c in aws_cloudfront_response_headers_policy.this.security_headers_config :
      alltrue([
        for h in c.strict_transport_security :
        h.access_control_max_age_sec == 63072000 && h.include_subdomains && h.preload && h.override
      ])
    ])
    error_message = "HSTS: max-age=63072000; includeSubDomains; preload, sobrescribiendo al origen."
  }
}

run "nosniff_frame_deny_and_referrer_policy" {
  command = plan

  assert {
    condition = alltrue([
      for c in aws_cloudfront_response_headers_policy.this.security_headers_config :
      alltrue([for h in c.content_type_options : h.override]) &&
      alltrue([for h in c.frame_options : h.frame_option == "DENY" && h.override]) &&
      alltrue([for h in c.referrer_policy : h.referrer_policy == "strict-origin-when-cross-origin" && h.override])
    ])
    error_message = "X-Content-Type-Options, X-Frame-Options DENY y Referrer-Policy strict-origin-when-cross-origin."
  }
}

run "csp_not_sent_by_default" {
  command = plan

  assert {
    condition     = alltrue([for c in aws_cloudfront_response_headers_policy.this.security_headers_config : length(c.content_security_policy) == 0])
    error_message = "Sin CSP configurada no se envía la cabecera."
  }
}

run "csp_sent_when_configured" {
  command = plan

  variables {
    content_security_policy = "default-src 'self'"
  }

  assert {
    condition = anytrue([
      for c in aws_cloudfront_response_headers_policy.this.security_headers_config :
      anytrue([for h in c.content_security_policy : h.content_security_policy == "default-src 'self'" && h.override])
    ])
    error_message = "La CSP indicada debe enviarse."
  }
}

run "policy_named_after_project_and_environment" {
  command = plan

  assert {
    condition     = aws_cloudfront_response_headers_policy.this.name == "acme-dev-security-headers"
    error_message = "Nombre <project>-<env>-security-headers."
  }
}

run "rejects_hsts_too_short_for_preload" {
  command = plan

  variables {
    hsts_max_age_seconds = 3600
  }

  expect_failures = [var.hsts_max_age_seconds]
}
