# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.

# Aceptación (a mano, ver README): un evento de prueba con source "orders.test" publicado en el bus aparece en S3
# en menos del intervalo de búfer; un evento que Firehose rechaza termina en la DLQ.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = output.bus_name != "" && length(output.dlq_arns) == 2
    error_message = "El bus debe crearse con una DLQ por cada regla."
  }
}
