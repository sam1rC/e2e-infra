# Requiere credenciales de la cuenta sandbox. Por defecto reutiliza el proveedor OIDC de GitHub de la cuenta;
# si no existe (cuenta nueva), lánzala creándolo:
#   tofu test -filter=tests/integration.tftest.hcl -var create_oidc_provider=true
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
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/", output.apply_role_arn))
    error_message = "El rol de apply debe crearse."
  }
}
