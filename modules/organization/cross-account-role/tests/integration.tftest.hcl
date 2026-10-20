# Coste cero (solo IAM). Corre en la sandbox:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/acme-dev-provider-", output.role_arn))
    error_message = "El rol entre cuentas debe crearse."
  }
}
