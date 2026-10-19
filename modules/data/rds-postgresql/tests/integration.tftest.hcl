# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.

# Además de lo que se comprueba aquí, la aceptación de la fase 6 exige (a mano, ver README):
# conexión sin TLS rechazada, MasterUserSecret presente y sin contraseña en el estado, y un PITR de prueba.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = output.endpoint != "" && output.app_secret_arn != ""
    error_message = "La instancia debe crearse con endpoint y secreto de aplicación."
  }
}
