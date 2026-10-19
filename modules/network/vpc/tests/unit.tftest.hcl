mock_provider "aws" {}

variables {
  project     = "acme"
  environment = "dev"
  cidr_block  = "10.20.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  flow_logs = {
    s3_bucket_arn = "arn:aws:s3:::acme-prod-security-logs-123456789012"
  }
}

# --- NAT ------------------------------------------------------------------------------------

run "regional_nat_has_no_public_subnets" {
  command = plan

  variables {
    nat_mode = "regional"
  }

  assert {
    condition     = length(aws_subnet.public) == 0 && length(aws_route_table.public) == 0
    error_message = "Con NAT regional no deben crearse subredes ni tabla públicas."
  }

  assert {
    condition     = length(aws_nat_gateway.regional) == 1 && length(aws_nat_gateway.zonal) == 0 && length(aws_eip.nat) == 0
    error_message = "Debe haber una única NAT regional, sin NAT zonales ni EIP explícitas."
  }

  assert {
    condition     = aws_nat_gateway.regional[0].availability_mode == "regional"
    error_message = "La NAT debe ser de modo regional."
  }
}

run "regional_nat_is_the_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.regional) == 1
    error_message = "nat_mode por defecto debe ser regional."
  }
}

run "zonal_single_creates_exactly_one_nat" {
  command = apply

  variables {
    nat_mode     = "zonal_single"
    subnet_tiers = { public = true }
  }

  assert {
    condition     = length(aws_nat_gateway.zonal) == 1 && contains(keys(aws_nat_gateway.zonal), "us-east-1a")
    error_message = "zonal_single debe crear una NAT en la primera AZ."
  }

  assert {
    condition     = length(toset([for r in aws_route.app_default : r.nat_gateway_id])) == 1 && length(aws_route.app_default) == 2
    error_message = "Todas las tablas app deben apuntar a la misma NAT."
  }
}

run "zonal_per_az_creates_one_nat_per_az" {
  command = apply

  variables {
    nat_mode     = "zonal_per_az"
    subnet_tiers = { public = true }
  }

  assert {
    condition     = length(aws_nat_gateway.zonal) == 2 && length(aws_eip.nat) == 2
    error_message = "zonal_per_az debe crear una NAT y una EIP por AZ."
  }

  assert {
    condition     = toset(keys(aws_route.app_default)) == toset(["us-east-1a", "us-east-1b"]) && toset(keys(aws_nat_gateway.zonal)) == toset(["us-east-1a", "us-east-1b"])
    error_message = "Debe haber una ruta por AZ y una NAT por AZ, con las mismas claves."
  }
}

run "no_nat_means_no_default_route_on_app" {
  command = plan

  variables {
    nat_mode = "none"
  }

  assert {
    condition     = length(aws_nat_gateway.zonal) == 0 && length(aws_nat_gateway.regional) == 0 && length(aws_route.app_default) == 0
    error_message = "Con nat_mode none no hay NAT ni rutas por defecto en app."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.nat_port_allocation) == 0
    error_message = "Sin NAT no hay alarma de puertos."
  }
}

run "port_allocation_alarm_per_nat" {
  command = apply

  variables {
    nat_mode      = "zonal_per_az"
    subnet_tiers  = { public = true }
    alarm_actions = ["arn:aws:sns:us-east-1:123456789012:alerts"]
  }

  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.nat_port_allocation) == 2 &&
      alltrue([for a in aws_cloudwatch_metric_alarm.nat_port_allocation : a.metric_name == "ErrorPortAllocation" && a.threshold == 0 && a.treat_missing_data == "notBreaching"])
    )
    error_message = "Debe existir una alarma ErrorPortAllocation > 0 por NAT."
  }
}

# --- Rutas y capas ----------------------------------------------------------------------------

run "data_tier_has_no_default_route" {
  command = apply

  # El mock reutiliza el mismo id en todas las tablas, así que no se compara por id: las únicas rutas
  # por defecto del módulo son app_default (claves = AZ de app) y public_default (inexistente aquí).
  # Que app_default solo referencia tablas app se comprueba sobre el plan real (ver README).
  assert {
    condition     = toset(keys(aws_route.app_default)) == toset(keys(aws_route_table.app)) && length(aws_route.public_default) == 0
    error_message = "Las tablas de la capa data no pueden tener ruta 0.0.0.0/0."
  }

  assert {
    condition     = length(aws_route_table.data) == 2
    error_message = "Debe existir una tabla data por AZ."
  }
}

run "public_tier_routes_to_the_internet_gateway" {
  command = plan

  variables {
    nat_mode     = "zonal_single"
    subnet_tiers = { public = true }
  }

  assert {
    condition     = length(aws_route.public_default) == 1 && length(aws_subnet.public) == 2
    error_message = "La capa pública debe tener una ruta por defecto al IGW y una subred por AZ."
  }
}

run "default_security_group_is_closed" {
  command = plan

  assert {
    condition     = length(aws_default_security_group.this.ingress) == 0 && length(aws_default_security_group.this.egress) == 0
    error_message = "El security group por defecto no puede tener reglas."
  }
}

run "dns_enabled_on_vpc" {
  command = plan

  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "La VPC necesita DNS support y hostnames (endpoints privados)."
  }
}

# --- CIDR y estabilidad ------------------------------------------------------------------------

run "subnet_cidrs_use_fixed_tier_offsets" {
  command = plan

  assert {
    condition = (
      aws_subnet.app["us-east-1a"].cidr_block == "10.20.64.0/20" &&
      aws_subnet.app["us-east-1b"].cidr_block == "10.20.80.0/20" &&
      aws_subnet.data["us-east-1a"].cidr_block == "10.20.128.0/20" &&
      aws_subnet.data["us-east-1b"].cidr_block == "10.20.144.0/20"
    )
    error_message = "Offsets fijos: app = 4, data = 8 (y public = 0) sobre cidrsubnet(/16, 4)."
  }
}

run "three_azs" {
  command = apply

  variables {
    az_names = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }

  assert {
    condition     = length(aws_subnet.app) == 3 && length(aws_subnet.data) == 3
    error_message = "Deben crearse tres subredes por capa."
  }
}

# for_each por nombre de AZ: quitar la última no cambia las direcciones (claves) ni los CIDR de las demás,
# luego OpenTofu no recrea sus subredes. (`tofu test` no permite comparar ids entre runs.)
run "removing_the_last_az_keeps_the_other_subnets" {
  command = apply

  assert {
    condition = (
      toset(keys(aws_subnet.app)) == toset(["us-east-1a", "us-east-1b"]) &&
      toset(keys(aws_subnet.data)) == toset(["us-east-1a", "us-east-1b"]) &&
      aws_subnet.app["us-east-1a"].cidr_block == "10.20.64.0/20" &&
      aws_subnet.app["us-east-1b"].cidr_block == "10.20.80.0/20" &&
      aws_subnet.data["us-east-1a"].cidr_block == "10.20.128.0/20" &&
      aws_subnet.data["us-east-1b"].cidr_block == "10.20.144.0/20"
    )
    error_message = "Quitar la última AZ conserva claves y CIDR de las demás y elimina solo la quitada."
  }
}

# --- NACL de la capa data ----------------------------------------------------------------------

run "data_nacl_only_admits_app_on_data_ports" {
  command = plan

  assert {
    condition = (
      length(aws_network_acl_rule.data_ingress_from_app) == 4 &&
      alltrue([for r in aws_network_acl_rule.data_ingress_from_app : r.protocol == "tcp" && r.rule_action == "allow" && r.egress == false && contains([5432, 6379], r.from_port) && r.from_port == r.to_port])
    )
    error_message = "La NACL data admite solo TCP 5432/6379 desde las subredes app (2 AZ x 2 puertos)."
  }

  assert {
    condition = alltrue([
      for r in aws_network_acl_rule.data_ingress_from_app :
      contains(["10.20.64.0/20", "10.20.80.0/20"], r.cidr_block)
    ])
    error_message = "El origen permitido son únicamente los CIDR de las subredes app."
  }
}

run "data_nacl_rule_numbers_are_unique_per_direction" {
  command = plan

  assert {
    condition = (
      length(toset([for r in aws_network_acl_rule.data_ingress_from_app : r.rule_number])) == length(aws_network_acl_rule.data_ingress_from_app) &&
      length(toset(concat(
        [for r in aws_network_acl_rule.data_ingress_from_app : r.rule_number],
        [for r in aws_network_acl_rule.data_ingress_internal : r.rule_number],
      ))) == length(aws_network_acl_rule.data_ingress_from_app) + length(aws_network_acl_rule.data_ingress_internal)
    )
    error_message = "Los números de regla de la NACL no pueden repetirse."
  }
}

run "data_nacl_internal_rules_allow_only_tcp_high_ports" {
  command = plan

  assert {
    condition = alltrue([
      for r in concat(values(aws_network_acl_rule.data_ingress_internal), values(aws_network_acl_rule.data_egress_internal)) :
      r.protocol == "tcp" && r.from_port == 1024 && r.to_port == 65535
    ])
    error_message = "El tráfico interno de la capa data solo admite TCP en puertos altos (datos y respuestas), nunca todos los protocolos."
  }
}

run "data_nacl_replies_only_to_app_ephemeral_ports" {
  command = plan

  assert {
    condition = alltrue([
      for r in aws_network_acl_rule.data_egress_to_app : r.from_port == 1024 && r.to_port == 65535 && r.egress
    ]) && length(aws_network_acl_rule.data_egress_to_app) == 2
    error_message = "La salida de data solo responde a app en puertos efímeros."
  }
}

run "no_nacl_without_both_tiers" {
  command = plan

  variables {
    subnet_tiers = { data = false }
  }

  assert {
    condition     = length(aws_network_acl.data) == 0 && length(aws_network_acl_rule.data_ingress_from_app) == 0
    error_message = "Sin capa data no se crea la NACL."
  }
}

# --- Flow logs y SSM ----------------------------------------------------------------------------

run "flow_logs_to_s3_with_extended_format" {
  command = plan

  assert {
    condition = (
      length(aws_flow_log.this) == 1 &&
      aws_flow_log.this[0].log_destination_type == "s3" &&
      aws_flow_log.this[0].traffic_type == "ALL" &&
      strcontains(aws_flow_log.this[0].log_format, "$${pkt-srcaddr}") &&
      strcontains(aws_flow_log.this[0].log_format, "$${traffic-path}")
    )
    error_message = "Flow logs a S3, tráfico ALL y formato extendido."
  }
}

run "flow_logs_can_be_disabled_explicitly" {
  command = plan

  variables {
    enable_flow_logs = false
    flow_logs        = null
  }

  assert {
    condition     = length(aws_flow_log.this) == 0
    error_message = "enable_flow_logs = false desactiva los flow logs."
  }
}

run "ssm_parameters_published_under_project_path" {
  command = plan

  assert {
    condition = toset(keys(aws_ssm_parameter.this)) == toset([
      "vpc_id", "vpc_cidr",
      "subnet_ids/app", "subnet_ids/data",
      "route_table_ids/app", "route_table_ids/data",
    ])
    error_message = "Se publican vpc, subredes y tablas de rutas de las capas activas."
  }

  assert {
    condition     = aws_ssm_parameter.this["vpc_cidr"].name == "/acme/dev/network/vpc_cidr" && aws_ssm_parameter.this["subnet_ids/app"].type == "StringList"
    error_message = "Los parámetros viven en /<project>/<env>/network/."
  }
}

run "ssm_publication_can_be_disabled" {
  command = plan

  variables {
    publish_ssm_parameters = false
  }

  assert {
    condition     = length(aws_ssm_parameter.this) == 0
    error_message = "publish_ssm_parameters = false no crea parámetros."
  }
}

# --- Validaciones -------------------------------------------------------------------------------

run "rejects_single_az" {
  command = plan

  variables {
    az_names = ["us-east-1a"]
  }

  expect_failures = [var.az_names]
}

run "rejects_duplicate_azs" {
  command = plan

  variables {
    az_names = ["us-east-1a", "us-east-1a"]
  }

  expect_failures = [var.az_names]
}

run "rejects_zonal_nat_without_public_tier" {
  command = plan

  variables {
    nat_mode = "zonal_single"
  }

  expect_failures = [var.subnet_tiers]
}

run "rejects_nat_without_app_tier" {
  command = plan

  variables {
    subnet_tiers = { app = false }
  }

  expect_failures = [var.subnet_tiers]
}

run "rejects_regional_nat_without_internet_gateway" {
  command = plan

  variables {
    create_internet_gateway = false
  }

  expect_failures = [var.create_internet_gateway]
}

run "rejects_oversized_cidr" {
  command = plan

  variables {
    cidr_block = "10.0.0.0/8"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_enabled_flow_logs_without_destination" {
  command = plan

  variables {
    flow_logs = null
  }

  expect_failures = [var.flow_logs]
}

run "rejects_internet_route_on_data_tier" {
  command = plan

  variables {
    data_subnet_internet_route = true
  }

  expect_failures = [var.data_subnet_internet_route]
}
