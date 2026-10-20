resource "aws_cloudfront_response_headers_policy" "this" {
  name    = "${var.project}-${var.environment}-security-headers"
  comment = "Cabeceras de seguridad de ${var.project}/${var.environment}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = var.hsts_max_age_seconds
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    dynamic "content_security_policy" {
      for_each = var.content_security_policy == null ? [] : [var.content_security_policy]

      content {
        content_security_policy = content_security_policy.value
        override                = true
      }
    }
  }
}
