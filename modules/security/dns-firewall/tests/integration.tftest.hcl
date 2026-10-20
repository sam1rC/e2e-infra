# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.

# Requiere IDs reales de las listas gestionadas de esta región (variable managed_domain_list_ids).
# Aceptación (a mano, ver README): resolver un dominio de la lista de prueba de AWS desde una instancia de la VPC
# devuelve NXDOMAIN y la consulta aparece en el log de S3.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = output.rule_group_id != ""
    error_message = "El grupo de reglas debe crearse y asociarse a la VPC."
  }
}
