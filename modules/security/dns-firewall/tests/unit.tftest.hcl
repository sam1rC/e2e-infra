mock_provider "aws" {}

variables {
  project     = "acme"
  environment = "dev"
  vpc_id      = "vpc-0123456789abcdef0"

  managed_domain_lists = {
    malware = { domain_list_id = "rslvr-fdl-0123456789abcdef", priority = 10 }
    botnet  = { domain_list_id = "rslvr-fdl-1123456789abcdef", priority = 20 }
    threats = { domain_list_id = "rslvr-fdl-2123456789abcdef", priority = 30 }
  }

  query_log_destination_arn = "arn:aws:s3:::acme-dev-logs-123456789012"
}

run "one_blocking_rule_per_managed_list_with_stable_priorities" {
  command = plan

  assert {
    condition     = toset(keys(aws_route53_resolver_firewall_rule.managed)) == toset(["malware", "botnet", "threats"])
    error_message = "Debe haber una regla por cada lista gestionada."
  }

  assert {
    condition = (
      alltrue([for r in aws_route53_resolver_firewall_rule.managed : r.action == "BLOCK" && r.block_response == "NXDOMAIN"]) &&
      aws_route53_resolver_firewall_rule.managed["malware"].priority == 10 &&
      aws_route53_resolver_firewall_rule.managed["threats"].priority == 30 &&
      aws_route53_resolver_firewall_rule.managed["botnet"].firewall_domain_list_id == "rslvr-fdl-1123456789abcdef"
    )
    error_message = "Las reglas bloquean con NXDOMAIN por defecto, con la prioridad y la lista indicadas."
  }
}

run "alert_rules_have_no_block_response" {
  command = plan

  variables {
    managed_domain_lists = {
      malware = { domain_list_id = "rslvr-fdl-0123456789abcdef", priority = 10, action = "ALERT" }
    }
  }

  assert {
    condition     = aws_route53_resolver_firewall_rule.managed["malware"].action == "ALERT" && aws_route53_resolver_firewall_rule.managed["malware"].block_response == null
    error_message = "block_response solo aplica a BLOCK."
  }
}

run "nodata_response_can_be_chosen_per_list" {
  command = plan

  variables {
    managed_domain_lists = {
      botnet = { domain_list_id = "rslvr-fdl-1123456789abcdef", priority = 20, block_response = "NODATA" }
    }
  }

  assert {
    condition     = aws_route53_resolver_firewall_rule.managed["botnet"].block_response == "NODATA"
    error_message = "block_response debe poder ser NODATA."
  }
}

run "rule_group_is_associated_to_the_vpc" {
  command = plan

  assert {
    condition = (
      aws_route53_resolver_firewall_rule_group.this.name == "acme-dev-dns-firewall" &&
      aws_route53_resolver_firewall_rule_group_association.this.vpc_id == "vpc-0123456789abcdef0" &&
      aws_route53_resolver_firewall_rule_group_association.this.priority == 101
    )
    error_message = "El grupo de reglas debe asociarse a la VPC con la prioridad por defecto (101)."
  }
}

run "mutation_protection_is_off_in_dev" {
  command = plan

  assert {
    condition     = aws_route53_resolver_firewall_rule_group_association.this.mutation_protection == "DISABLED"
    error_message = "En dev la protección contra desasociación está desactivada por defecto."
  }
}

run "prod_enables_mutation_protection" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = aws_route53_resolver_firewall_rule_group_association.this.mutation_protection == "ENABLED"
    error_message = "En prod la protección contra desasociación debe estar activa."
  }
}

run "mutation_protection_can_be_overridden" {
  command = plan

  variables {
    environment         = "prod"
    mutation_protection = false
  }

  assert {
    condition     = aws_route53_resolver_firewall_rule_group_association.this.mutation_protection == "DISABLED"
    error_message = "mutation_protection = false debe poder anular el valor por defecto."
  }
}

run "firewall_fails_closed_by_default" {
  command = plan

  assert {
    condition     = aws_route53_resolver_firewall_config.this.firewall_fail_open == "DISABLED" && aws_route53_resolver_firewall_config.this.resource_id == "vpc-0123456789abcdef0"
    error_message = "Por defecto el firewall rechaza las consultas que no puede evaluar (fail closed)."
  }
}

run "fail_open_can_be_enabled" {
  command = plan

  variables {
    fail_open = true
  }

  assert {
    condition     = aws_route53_resolver_firewall_config.this.firewall_fail_open == "ENABLED"
    error_message = "fail_open = true debe activar el modo fail open."
  }
}

run "query_logs_go_to_the_bucket_and_are_associated_to_the_vpc" {
  command = plan

  assert {
    condition = (
      aws_route53_resolver_query_log_config.this.destination_arn == "arn:aws:s3:::acme-dev-logs-123456789012" &&
      aws_route53_resolver_query_log_config_association.this.resource_id == "vpc-0123456789abcdef0"
    )
    error_message = "Los logs de consultas deben ir al bucket y asociarse a la VPC."
  }
}

run "query_log_destination_accepts_a_prefix" {
  command = plan

  variables {
    query_log_destination_arn = "arn:aws:s3:::acme-dev-logs-123456789012/dns"
  }

  assert {
    condition     = aws_route53_resolver_query_log_config.this.destination_arn == "arn:aws:s3:::acme-dev-logs-123456789012/dns"
    error_message = "El destino debe admitir un prefijo dentro del bucket."
  }
}

run "rejects_empty_domain_lists" {
  command = plan

  variables {
    managed_domain_lists = {}
  }

  expect_failures = [var.managed_domain_lists]
}

run "rejects_duplicated_priorities" {
  command = plan

  variables {
    managed_domain_lists = {
      malware = { domain_list_id = "rslvr-fdl-0123456789abcdef", priority = 10 }
      botnet  = { domain_list_id = "rslvr-fdl-1123456789abcdef", priority = 10 }
    }
  }

  expect_failures = [var.managed_domain_lists]
}

run "rejects_priority_above_10000" {
  command = plan

  variables {
    managed_domain_lists = {
      malware = { domain_list_id = "rslvr-fdl-0123456789abcdef", priority = 10001 }
    }
  }

  expect_failures = [var.managed_domain_lists]
}

run "rejects_invalid_domain_list_id" {
  command = plan

  variables {
    managed_domain_lists = {
      malware = { domain_list_id = "AWSManagedDomainsMalwareDomainList", priority = 10 }
    }
  }

  expect_failures = [var.managed_domain_lists]
}

run "rejects_invalid_action" {
  command = plan

  variables {
    managed_domain_lists = {
      malware = { domain_list_id = "rslvr-fdl-0123456789abcdef", priority = 10, action = "DENY" }
    }
  }

  expect_failures = [var.managed_domain_lists]
}

run "rejects_invalid_block_response" {
  command = plan

  variables {
    managed_domain_lists = {
      malware = { domain_list_id = "rslvr-fdl-0123456789abcdef", priority = 10, block_response = "REFUSED" }
    }
  }

  expect_failures = [var.managed_domain_lists]
}

run "rejects_log_destination_that_is_not_a_bucket" {
  command = plan

  variables {
    query_log_destination_arn = "arn:aws:logs:us-east-1:123456789012:log-group:dns"
  }

  expect_failures = [var.query_log_destination_arn]
}

run "rejects_association_priority_below_101" {
  command = plan

  variables {
    association_priority = 100
  }

  expect_failures = [var.association_priority]
}
