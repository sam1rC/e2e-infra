# Requiere la cuenta de management de una organización sandbox y una OU de pruebas vacía (variables target_id y organization_id); las SCP se adjuntan a esa OU.
# Corre solo en main/nightly:  tofu test -filter=tests/integration.tftest.hcl
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
    condition     = can(regex("^p-", output.security_policy_id))
    error_message = "El ejemplo complete debe crearse y devolver security_policy_id."
  }
}
