# Integración del blueprint E-commerce T3 en la cuenta sandbox (docs/test-plan-sandbox.md, oleada B1).
# Requiere credenciales de una identidad no raíz, una zona de Route 53 delegada y el subdominio de prueba:
#   tofu -chdir=blueprints/ecommerce-t3 init
#   tofu -chdir=blueprints/ecommerce-t3 test -filter=tests/integration.tftest.hcl \
#     -var account_id=<cuenta> -var zone_id=<zona> -var domain_name=t3.<dominio>
# `tofu test` destruye todo al terminar (también si una aserción falla). La idempotencia se comprueba con
# el segundo run (plan sobre el mismo estado) y las pruebas de comportamiento (curl, 403 directo) en el
# runbook de la campaña, con el entorno aplicado a mano.

variables {
  name_suffix = "t3i"
}

run "apply" {
  command = apply

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = endswith(output.distribution_domain_name, ".cloudfront.net")
    error_message = "La distribución debe crearse."
  }

  assert {
    condition     = startswith(output.api_endpoint, "https://")
    error_message = "La HTTP API debe tener endpoint."
  }
}

run "idempotent" {
  command = plan

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = output.url == "https://${var.domain_name}"
    error_message = "El plan sobre el estado aplicado debe evaluarse sin errores."
  }
}
