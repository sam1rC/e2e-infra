resource "aws_wafv2_web_acl" "this" {
  count = var.create_web_acl ? 1 : 0

  name        = local.name
  description = "Web ACL ${var.scope} de ${var.project}/${var.environment}"
  scope       = var.scope

  default_action {
    allow {}
  }

  # Verificación de origen: bloquea lo que no lleve la cabecera esperada (prioridad 5, evalúa primero).
  dynamic "rule" {
    for_each = var.origin_verify == null ? [] : [1]

    content {
      name     = "origin-verify"
      priority = 5

      action {
        block {}
      }

      statement {
        not_statement {
          statement {
            byte_match_statement {
              search_string         = var.origin_verify.secret
              positional_constraint = "EXACTLY"

              field_to_match {
                single_header {
                  name = lower(var.origin_verify.header_name)
                }
              }

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = false # la muestra incluiría el valor de la cabecera secreta
        metric_name                = "${local.name}-origin-verify"
      }
    }
  }

  dynamic "rule" {
    for_each = local.managed_rules

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = local.count_mode || (rule.key == "anonymous_ip" && var.anonymous_ip_list_mode == "count") ? [] : [1]

          content {}
        }

        dynamic "count" {
          for_each = local.count_mode || (rule.key == "anonymous_ip" && var.anonymous_ip_list_mode == "count") ? [1] : []

          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = rule.key == "common" && var.count_size_restrictions_body ? [1] : []

            content {
              name = "SizeRestrictions_BODY"

              action_to_use {
                count {}
              }
            }
          }

          dynamic "managed_rule_group_configs" {
            for_each = contains(["bot_control", "anti_ddos"], rule.key) ? [1] : []

            content {
              dynamic "aws_managed_rules_bot_control_rule_set" {
                for_each = rule.key == "bot_control" ? [1] : []

                content {
                  inspection_level = "COMMON"
                }
              }

              dynamic "aws_managed_rules_anti_ddos_rule_set" {
                for_each = rule.key == "anti_ddos" ? [var.anti_ddos] : []

                content {
                  sensitivity_to_block = aws_managed_rules_anti_ddos_rule_set.value.sensitivity_to_block

                  client_side_action_config {
                    challenge {
                      usage_of_action = aws_managed_rules_anti_ddos_rule_set.value.challenge_enabled ? "ENABLED" : "DISABLED"
                      sensitivity     = aws_managed_rules_anti_ddos_rule_set.value.challenge_sensitivity

                      dynamic "exempt_uri_regular_expression" {
                        for_each = aws_managed_rules_anti_ddos_rule_set.value.exempt_uri_regexes

                        content {
                          regex_string = exempt_uri_regular_expression.value
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "${local.name}-${rule.key}"
      }
    }
  }

  rule {
    name     = "rate-limit-per-ip"
    priority = 50

    action {
      dynamic "block" {
        for_each = local.count_mode ? [] : [1]

        content {}
      }

      dynamic "count" {
        for_each = local.count_mode ? [1] : []

        content {}
      }
    }

    statement {
      rate_based_statement {
        limit                 = var.rate_limit_per_5m
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name}-rate-ip"
    }
  }

  dynamic "rule" {
    for_each = var.tenant_rate_limit == null ? [] : [var.tenant_rate_limit]

    content {
      name     = "rate-limit-per-tenant"
      priority = 55

      action {
        dynamic "block" {
          for_each = local.count_mode ? [] : [1]

          content {}
        }

        dynamic "count" {
          for_each = local.count_mode ? [1] : []

          content {}
        }
      }

      statement {
        rate_based_statement {
          limit                 = rule.value.limit
          aggregate_key_type    = "CUSTOM_KEYS"
          evaluation_window_sec = 300

          custom_key {
            header {
              name = rule.value.header_name

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "${local.name}-rate-tenant"
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = local.name
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "this" {
  for_each = var.create_web_acl ? var.association_arns : {}

  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
