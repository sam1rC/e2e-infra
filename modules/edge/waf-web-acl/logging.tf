# El nombre debe empezar por aws-waf-logs- para que WAF lo acepte como destino.
resource "aws_cloudwatch_log_group" "waf" {
  count = var.create_web_acl ? 1 : 0

  name              = "aws-waf-logs-${local.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn

  tags = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.create_web_acl ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  dynamic "redacted_fields" {
    for_each = var.origin_verify == null ? [] : [1]

    content {
      single_header {
        name = lower(var.origin_verify.header_name)
      }
    }
  }
}
