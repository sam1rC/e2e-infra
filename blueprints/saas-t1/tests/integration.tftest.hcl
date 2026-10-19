# Integración del blueprint saas-t1 en la cuenta sandbox (docs/test-plan-sandbox.md). Aplica las capas en
# orden (control-plane → app-network → app-data → app-app → app-edge) con estado local por capa y `tofu test` las destruye en orden inverso al terminar
# (también si una aserción falla). Requiere una identidad no raíz, una zona de Route 53 delegada y una
# imagen por digest:
#   tofu -chdir=blueprints/saas-t1 init
#   tofu -chdir=blueprints/saas-t1 test -filter=tests/integration.tftest.hcl \
#     -var account_id=<cuenta> -var zone_id=<zona> -var domain_name=<sub>.<dominio> -var image=<repo@sha256:...>
# Las pruebas de comportamiento (HTTPS 200, WAF 403, DNS privado del ALB, failover) se hacen con el entorno
# aplicado a mano según la campaña. Todo en una sola cuenta: las capas security (AWS Organizations)
# y silo (cuenta del tenant) se validan solo con plan; este test valida que las capas se componen, aplican y destruyen.

variables {
  name_suffix = "s1i"
}

run "control_plane" {
  command = apply

  module {
    source = "./examples/complete/control-plane"
  }

  assert {
    condition     = length(output.issuers) == 1
    error_message = "Debe crearse el user pool del tier basic."
  }
}

run "app_network" {
  command = apply

  module {
    source = "./examples/complete/app-network"
  }

  assert {
    condition     = startswith(output.vpc_id, "vpc-")
    error_message = "La VPC debe crearse."
  }
}

run "app_data" {
  command = apply

  module {
    source = "./examples/complete/app-data"
  }

  assert {
    condition     = output.aurora_cluster_id != ""
    error_message = "Aurora debe crearse."
  }
}

run "app_app" {
  command = apply

  module {
    source = "./examples/complete/app-app"
  }

  variables {
    jwt_issuers      = run.control_plane.issuers
    metering_bus_arn = run.control_plane.event_bus_arn
  }

  assert {
    condition     = startswith(output.alb_dns_name, "internal-")
    error_message = "El ALB debe ser interno."
  }
}

run "app_edge" {
  command = apply

  module {
    source = "./examples/complete/app-edge"
  }

  assert {
    condition     = endswith(output.distribution_domain_name, ".cloudfront.net")
    error_message = "La distribución debe crearse."
  }
}
