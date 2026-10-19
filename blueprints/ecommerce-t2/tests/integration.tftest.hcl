# Integración del blueprint ecommerce-t2 en la cuenta sandbox (docs/test-plan-sandbox.md). Aplica las capas en
# orden (network → data → app → edge) con estado local por capa y `tofu test` las destruye en orden inverso al terminar
# (también si una aserción falla). Requiere una identidad no raíz, una zona de Route 53 delegada y una
# imagen por digest:
#   tofu -chdir=blueprints/ecommerce-t2 init
#   tofu -chdir=blueprints/ecommerce-t2 test -filter=tests/integration.tftest.hcl \
#     -var account_id=<cuenta> -var zone_id=<zona> -var domain_name=<sub>.<dominio> -var image=<repo@sha256:...>
# Las pruebas de comportamiento (HTTPS 200, WAF 403, DNS privado del ALB, failover) se hacen con el entorno
# aplicado a mano según la campaña; este test valida que las capas se componen, aplican y destruyen.

variables {
  name_suffix = "t2i"
}

run "network" {
  command = apply

  module {
    source = "./examples/complete/network"
  }

  assert {
    condition     = startswith(output.vpc_id, "vpc-")
    error_message = "La VPC debe crearse."
  }
}

run "data" {
  command = apply

  module {
    source = "./examples/complete/data"
  }

  assert {
    condition     = output.instance_id != ""
    error_message = "La base de datos debe crearse."
  }
}

run "app" {
  command = apply

  module {
    source = "./examples/complete/app"
  }

  assert {
    condition     = startswith(output.alb_dns_name, "internal-")
    error_message = "El ALB debe ser interno."
  }
}

run "edge" {
  command = apply

  module {
    source = "./examples/complete/edge"
  }

  assert {
    condition     = endswith(output.distribution_domain_name, ".cloudfront.net")
    error_message = "La distribución debe crearse."
  }
}
