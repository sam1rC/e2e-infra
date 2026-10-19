# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.
#
# El ejemplo sube un paquete mínimo (app.py) a un bucket propio, así que no necesita pipeline.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = can(regex("^arn:aws:lambda:[a-z0-9-]+:[0-9]{12}:function:acme-", output.function_arn))
    error_message = "La función debe crearse."
  }

  assert {
    condition     = can(regex("^arn:aws:sqs:", output.dlq_arn))
    error_message = "La cola DLQ debe crearse."
  }
}
