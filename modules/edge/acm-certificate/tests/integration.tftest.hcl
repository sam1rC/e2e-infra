# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.
#
# La zona de pruebas no está delegada, así que el certificado se crea pero no llega a emitirse
# (wait_for_validation = false); se verifica la creación del certificado y de sus registros.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = can(regex("^arn:aws:acm:us-east-1:", output.certificate_arn)) && length(output.validation_records) == 2
    error_message = "El certificado de us-east-1 y sus dos registros de validación deben crearse."
  }
}
