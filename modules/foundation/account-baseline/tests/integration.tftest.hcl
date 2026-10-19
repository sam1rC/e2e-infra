# Requiere una cuenta sandbox DEDICADA y vacía: la línea base es de cuenta (GuardDuty, Security Hub, Config, EBS por defecto...) y solo puede existir una por región.
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
    condition     = can(regex("^arn:aws:sns:", output.alerts_topic_arn))
    error_message = "El ejemplo complete debe crearse y devolver alerts_topic_arn."
  }
}
