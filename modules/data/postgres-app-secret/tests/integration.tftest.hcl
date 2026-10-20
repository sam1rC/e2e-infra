# Requiere credenciales de la cuenta sandbox y una base PostgreSQL con secreto maestro gestionado por RDS
# (variable master_secret_arn). Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = output.rotation_lambda_arn != null
    error_message = "La función de rotación debe desplegarse."
  }
}
