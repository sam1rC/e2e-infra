# Integración del blueprint SaaS T3 en la cuenta sandbox (docs/test-plan-sandbox.md, oleada B1).
# Requiere credenciales de una identidad no raíz, una zona de Route 53 delegada y el subdominio de prueba:
#   tofu -chdir=blueprints/saas-t3 init
#   tofu -chdir=blueprints/saas-t3 test -filter=tests/integration.tftest.hcl \
#     -var account_id=<cuenta> -var zone_id=<zona> -var domain_name=s3.<dominio>
# `tofu test` destruye todo al terminar (también si una aserción falla). La idempotencia se comprueba con
# el segundo run (plan sobre el mismo estado) y las pruebas de comportamiento (curl, 403 directo) en el
# runbook de la campaña, con el entorno aplicado a mano.

variables {
  name_suffix = "s3i"
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
    condition     = endswith(output.api_invoke_url, "/v1")
    error_message = "La REST API debe desplegar la etapa v1."
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
