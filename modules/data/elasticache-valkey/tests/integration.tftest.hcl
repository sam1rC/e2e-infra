# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.

# La conexión con un token IAM y el rechazo de conexiones sin TLS o sin credenciales se prueban a mano
# desde una tarea de la VPC (ver README).

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = output.primary_endpoint != "" && length(output.iam_connect_resource_arns) == 2
    error_message = "El replication group debe crearse con un usuario IAM por cada entrada de iam_users."
  }
}
