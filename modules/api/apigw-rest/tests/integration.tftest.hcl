# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. Coste: WAF regional (5 USD/mes + 1 USD/regla, prorrateado por hora),
# REST API, Lambda y Cognito por uso. El ejemplo fija el rol de CloudWatch de API Gateway de la cuenta.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = can(regex("^https://[a-z0-9]+\\.execute-api\\.us-east-1\\.amazonaws\\.com/v1$", output.invoke_url)) && length(output.usage_plan_ids) == 2
    error_message = "La REST API debe crearse con su etapa y los dos planes de uso."
  }
}

# Aceptación de la fase 8, paso 7: llamar al endpoint de API Gateway sin pasar por CloudFront (sin la cabecera
# x-origin-verify) devuelve 403 del WAF; con la cabecera pero sin token, 401 del autorizador de Cognito.
run "direct_calls_without_origin_header_are_blocked" {
  command = apply

  module {
    source = "./tests/http-check"
  }

  variables {
    url                 = "${run.apply_complete_example.invoke_url}/orders"
    origin_verify_token = "valor-de-prueba-no-secreto-0123456789abcdef"
  }

  assert {
    condition     = output.without_header_status == 403
    error_message = "Sin x-origin-verify el WAF regional debe devolver 403."
  }

  assert {
    condition     = output.with_header_status == 401
    error_message = "Con la cabecera pero sin token, el autorizador de Cognito debe devolver 401."
  }
}
