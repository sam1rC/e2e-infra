resource "aws_route53_resolver_firewall_rule_group" "this" {
  name = local.name

  tags = merge(var.tags, { Name = local.name })
}

# Las listas gestionadas por AWS se actualizan solas: no hay dominios en el código.
resource "aws_route53_resolver_firewall_rule" "managed" {
  for_each = var.managed_domain_lists

  name                    = "${local.name}-${each.key}"
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.this.id
  firewall_domain_list_id = each.value.domain_list_id
  priority                = each.value.priority
  action                  = each.value.action
  block_response          = each.value.action == "BLOCK" ? each.value.block_response : null
}

resource "aws_route53_resolver_firewall_rule_group_association" "this" {
  name                   = local.name
  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.this.id
  vpc_id                 = var.vpc_id
  priority               = var.association_priority
  mutation_protection    = local.mutation_protection ? "ENABLED" : "DISABLED"

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_route53_resolver_firewall_config" "this" {
  resource_id        = var.vpc_id
  firewall_fail_open = var.fail_open ? "ENABLED" : "DISABLED"
}

resource "aws_route53_resolver_query_log_config" "this" {
  name            = local.name
  destination_arn = var.query_log_destination_arn

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_route53_resolver_query_log_config_association" "this" {
  resolver_query_log_config_id = aws_route53_resolver_query_log_config.this.id
  resource_id                  = var.vpc_id
}
