# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.
#
# Los endpoints de interfaz se cobran por hora y AZ: el ejemplo se destruye al terminar la prueba.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = length(output.interface_endpoint_ids) == 10 && length(output.gateway_endpoint_ids) == 2
    error_message = "Deben crearse 10 endpoints de interfaz y 2 gateway."
  }
}
