mock_provider "aws" {
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:aws-waf-logs-mock"
    }
  }

  mock_resource "aws_wafv2_web_acl" {
    defaults = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/mock/11111111-2222-3333-4444-555555555555"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  scope       = "CLOUDFRONT"
}

run "default_rules_in_fixed_priority_order" {
  command = plan

  assert {
    condition = {
      for r in aws_wafv2_web_acl.this[0].rule : r.name => r.priority
      } == {
      "AWSManagedRulesAmazonIpReputationList" = 10
      "AWSManagedRulesCommonRuleSet"          = 20
      "AWSManagedRulesKnownBadInputsRuleSet"  = 30
      "AWSManagedRulesSQLiRuleSet"            = 40
      "rate-limit-per-ip"                     = 50
    }
    error_message = "Reglas y prioridades por defecto: reputación IP 10, común 20, entradas maliciosas 30, SQLi 40, tasa 50."
  }

  assert {
    condition     = aws_wafv2_web_acl.this[0].name == "acme-dev-cloudfront" && aws_wafv2_web_acl.this[0].scope == "CLOUDFRONT"
    error_message = "Nombre <project>-<env>-<scope> y ámbito CLOUDFRONT."
  }

  assert {
    condition     = alltrue([for d in aws_wafv2_web_acl.this[0].default_action : length(d.allow) == 1 && length(d.block) == 0])
    error_message = "La acción por defecto es permitir; las reglas bloquean."
  }
}

run "managed_groups_enforce_by_default" {
  command = plan

  assert {
    condition = alltrue([
      for r in aws_wafv2_web_acl.this[0].rule :
      length(r.override_action) == 0 || alltrue([for o in r.override_action : length(o.none) == 1 && length(o.count) == 0])
    ])
    error_message = "Los grupos gestionados deben aplicar sus acciones (override none)."
  }

  assert {
    condition = alltrue([
      for r in aws_wafv2_web_acl.this[0].rule :
      r.name != "rate-limit-per-ip" || alltrue([for a in r.action : length(a.block) == 1])
    ])
    error_message = "La regla de tasa bloquea por defecto."
  }
}

run "count_mode_only_observes" {
  command = plan

  variables {
    managed_rules_mode = "count"
  }

  assert {
    condition = alltrue([
      for r in aws_wafv2_web_acl.this[0].rule :
      (length(r.override_action) == 0 || alltrue([for o in r.override_action : length(o.count) == 1 && length(o.none) == 0])) &&
      (length(r.action) == 0 || alltrue([for a in r.action : length(a.count) == 1 && length(a.block) == 0]))
    ])
    error_message = "En modo count ni los grupos gestionados ni la regla de tasa bloquean."
  }
}

run "rate_limit_follows_input" {
  command = plan

  variables {
    rate_limit_per_5m = 750
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this[0].rule :
      r.name == "rate-limit-per-ip" && alltrue([for s in r.statement : alltrue([for rb in s.rate_based_statement : rb.limit == 750 && rb.aggregate_key_type == "IP" && rb.evaluation_window_sec == 300])])
    ])
    error_message = "El límite por IP en 5 minutos sale de rate_limit_per_5m."
  }
}

run "size_restrictions_body_override_is_optional" {
  command = plan

  variables {
    count_size_restrictions_body = true
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this[0].rule :
      r.name == "AWSManagedRulesCommonRuleSet" && anytrue([
        for s in r.statement : anytrue([
          for m in s.managed_rule_group_statement : anytrue([for o in m.rule_action_override : o.name == "SizeRestrictions_BODY"])
        ])
      ])
    ])
    error_message = "SizeRestrictions_BODY debe quedar en count dentro de CommonRuleSet."
  }
}

run "bot_control_is_opt_in" {
  command = plan

  variables {
    enable_bot_control = true
  }

  assert {
    condition     = anytrue([for r in aws_wafv2_web_acl.this[0].rule : r.name == "AWSManagedRulesBotControlRuleSet" && r.priority == 60])
    error_message = "Bot Control debe añadirse con prioridad 60 cuando se activa."
  }
}

run "anti_ddos_runs_first_with_its_configuration" {
  command = plan

  variables {
    anti_ddos = {}
  }

  assert {
    condition     = length([for r in aws_wafv2_web_acl.this[0].rule : r if r.name == "AWSManagedRulesAntiDDoSRuleSet" && r.priority == 1]) == 1
    error_message = "Anti-DDoS debe añadirse con prioridad 1 cuando se activa."
  }

  assert {
    condition = alltrue([
      for r in aws_wafv2_web_acl.this[0].rule : alltrue([
        for c in r.statement[0].managed_rule_group_statement[0].managed_rule_group_configs[0].aws_managed_rules_anti_ddos_rule_set :
        c.sensitivity_to_block == "LOW" &&
        c.client_side_action_config[0].challenge[0].usage_of_action == "ENABLED" &&
        c.client_side_action_config[0].challenge[0].sensitivity == "HIGH" &&
        length(c.client_side_action_config[0].challenge[0].exempt_uri_regular_expression) == 2
      ]) if r.name == "AWSManagedRulesAntiDDoSRuleSet"
    ])
    error_message = "Por defecto: bloqueo LOW, challenge activado en HIGH y 2 expresiones exentas (API y estáticos)."
  }
}

run "anti_ddos_challenge_can_be_disabled" {
  command = plan

  variables {
    anti_ddos = {
      sensitivity_to_block = "MEDIUM"
      challenge_enabled    = false
      exempt_uri_regexes   = []
    }
  }

  assert {
    condition = alltrue([
      for r in aws_wafv2_web_acl.this[0].rule : alltrue([
        for c in r.statement[0].managed_rule_group_statement[0].managed_rule_group_configs[0].aws_managed_rules_anti_ddos_rule_set :
        c.sensitivity_to_block == "MEDIUM" &&
        c.client_side_action_config[0].challenge[0].usage_of_action == "DISABLED" &&
        length(c.client_side_action_config[0].challenge[0].exempt_uri_regular_expression) == 0
      ]) if r.name == "AWSManagedRulesAntiDDoSRuleSet"
    ]) && length([for r in aws_wafv2_web_acl.this[0].rule : r if r.name == "AWSManagedRulesAntiDDoSRuleSet"]) == 1
    error_message = "La configuración de Anti-DDoS debe seguir la variable."
  }
}

run "anonymous_ip_list_starts_in_count" {
  command = plan

  variables {
    anonymous_ip_list_mode = "count"
  }

  assert {
    condition     = length([for r in aws_wafv2_web_acl.this[0].rule : r if r.name == "AWSManagedRulesAnonymousIpList" && r.priority == 15 && length(r.override_action[0].count) == 1 && length(r.override_action[0].none) == 0]) == 1
    error_message = "En modo count la lista de IPs anónimas solo registra (override count), con prioridad 15."
  }

  assert {
    condition     = alltrue([for r in aws_wafv2_web_acl.this[0].rule : length(r.override_action[0].none) == 1 if r.name == "AWSManagedRulesCommonRuleSet"])
    error_message = "El modo count de la lista anónima no afecta al resto de grupos."
  }
}

run "anonymous_ip_list_can_block" {
  command = plan

  variables {
    anonymous_ip_list_mode = "block"
  }

  assert {
    condition     = length([for r in aws_wafv2_web_acl.this[0].rule : r if r.name == "AWSManagedRulesAnonymousIpList" && length(r.override_action[0].none) == 1]) == 1
    error_message = "En modo block la lista de IPs anónimas aplica sus acciones."
  }
}

run "tenant_rate_limit_uses_custom_key" {
  command = plan

  variables {
    tenant_rate_limit = { header_name = "x-tenant-id", limit = 500 }
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this[0].rule :
      r.name == "rate-limit-per-tenant" && r.priority == 55 && alltrue([
        for s in r.statement : alltrue([for rb in s.rate_based_statement : rb.aggregate_key_type == "CUSTOM_KEYS" && rb.limit == 500])
      ])
    ])
    error_message = "La regla por tenant agrega por cabecera con CUSTOM_KEYS."
  }
}

run "origin_verify_blocks_missing_header" {
  command = plan

  variables {
    scope = "REGIONAL"
    origin_verify = {
      secret = "token-de-prueba"
    }
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this[0].rule :
      r.name == "origin-verify" && r.priority == 5 && alltrue([for a in r.action : length(a.block) == 1])
    ])
    error_message = "La verificación de origen bloquea y evalúa antes que el resto de reglas."
  }

  assert {
    condition     = anytrue([for f in aws_wafv2_web_acl_logging_configuration.this[0].redacted_fields : anytrue([for h in f.single_header : h.name == "x-origin-verify"])])
    error_message = "El logging debe ocultar la cabecera secreta de verificación."
  }
}

run "logging_redacts_credentials_and_uses_waf_log_group" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.waf[0].name == "aws-waf-logs-acme-dev-cloudfront" && aws_cloudwatch_log_group.waf[0].retention_in_days == 90
    error_message = "El grupo de logs debe empezar por aws-waf-logs- y retener 90 días por defecto."
  }

  assert {
    condition = toset(flatten([
      for f in aws_wafv2_web_acl_logging_configuration.this[0].redacted_fields : [for h in f.single_header : h.name]
    ])) == toset(["authorization", "cookie"])
    error_message = "Deben ocultarse las cabeceras authorization y cookie."
  }
}

run "flat_rate_plan_creates_nothing" {
  command = plan

  variables {
    create_web_acl = false
  }

  assert {
    condition     = length(aws_wafv2_web_acl.this) == 0 && length(aws_cloudwatch_log_group.waf) == 0 && length(aws_wafv2_web_acl_logging_configuration.this) == 0
    error_message = "Con create_web_acl = false no se crea nada."
  }

  assert {
    condition     = output.web_acl_arn == null && output.web_acl_id == null
    error_message = "Los outputs deben ser null sin Web ACL."
  }
}

run "regional_associations_keyed_by_name" {
  command = plan

  variables {
    scope = "REGIONAL"
    association_arns = {
      api = "arn:aws:apigateway:us-east-1::/restapis/abc123/stages/prod"
    }
  }

  assert {
    condition     = toset(keys(aws_wafv2_web_acl_association.this)) == toset(["api"])
    error_message = "Una asociación por recurso, con clave estable."
  }
}

run "rejects_associations_for_cloudfront_scope" {
  command = plan

  variables {
    association_arns = {
      api = "arn:aws:apigateway:us-east-1::/restapis/abc123/stages/prod"
    }
  }

  expect_failures = [var.association_arns]
}

run "rejects_origin_verify_for_cloudfront_scope" {
  command = plan

  variables {
    origin_verify = { secret = "x" }
  }

  expect_failures = [var.origin_verify]
}

run "rejects_unknown_scope" {
  command = plan

  variables {
    scope = "GLOBAL"
  }

  expect_failures = [var.scope]
}

run "rejects_rate_limit_below_waf_minimum" {
  command = plan

  variables {
    rate_limit_per_5m = 5
  }

  expect_failures = [var.rate_limit_per_5m]
}

run "rejects_unsupported_log_retention" {
  command = plan

  variables {
    log_retention_days = 45
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_unknown_anti_ddos_sensitivity" {
  command = plan

  variables {
    anti_ddos = { sensitivity_to_block = "EXTREME" }
  }

  expect_failures = [var.anti_ddos]
}

run "rejects_unknown_anonymous_ip_mode" {
  command = plan

  variables {
    anonymous_ip_list_mode = "on"
  }

  expect_failures = [var.anonymous_ip_list_mode]
}
