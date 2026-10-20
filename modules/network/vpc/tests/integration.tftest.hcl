# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.
#
# examples/complete usa NAT regional: este test es la verificación real de ese recurso con la versión
# del provider elegida (ADR 0001). Anota aquí el resultado antes de fijar la versión en una composición.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = can(regex("^vpc-", output.vpc_id)) && contains(keys(output.nat_gateway_ids), "regional")
    error_message = "La VPC y la NAT regional deben crearse."
  }
}
