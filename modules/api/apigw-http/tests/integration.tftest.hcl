# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. Coste: HTTP API, Lambda y Cognito cobran por uso (sin tráfico, ~0).

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = can(regex("^https://[a-z0-9]+\\.execute-api\\.us-east-1\\.amazonaws\\.com$", output.api_endpoint))
    error_message = "La HTTP API debe crearse con su endpoint execute-api."
  }
}

# Una ruta JWT sin token devuelve 401 y la pública responde (la Lambda de ejemplo devuelve 200).
run "jwt_routes_reject_anonymous_requests" {
  command = apply

  module {
    source = "./tests/http-check"
  }

  variables {
    protected_url = "${run.apply_complete_example.api_endpoint}/orders"
    public_url    = "${run.apply_complete_example.api_endpoint}/products"
  }

  assert {
    condition     = output.protected_status == 401 && output.public_status == 200
    error_message = "GET /orders sin token debe dar 401 y GET /products 200."
  }
}
