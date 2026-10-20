locals {
  name       = "${var.project}-${var.environment}-${lower(var.scope)}"
  count_mode = var.managed_rules_mode == "count"

  # Prioridades fijas: ordenar o quitar una regla no renumera las demás.
  managed_rules = merge(
    {
      ip_reputation = { name = "AWSManagedRulesAmazonIpReputationList", priority = 10 }
      common        = { name = "AWSManagedRulesCommonRuleSet", priority = 20 }
      bad_inputs    = { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 30 }
      sqli          = { name = "AWSManagedRulesSQLiRuleSet", priority = 40 }
    },
    var.enable_bot_control ? { bot_control = { name = "AWSManagedRulesBotControlRuleSet", priority = 60 } } : {},
    # Anti-DDoS va antes que cualquier regla que no sea Allow (guía de AWS) para medir todo el tráfico.
    var.anti_ddos == null ? {} : { anti_ddos = { name = "AWSManagedRulesAntiDDoSRuleSet", priority = 1 } },
    var.anonymous_ip_list_mode == "off" ? {} : { anonymous_ip = { name = "AWSManagedRulesAnonymousIpList", priority = 15 } },
  )
}
