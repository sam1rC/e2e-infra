# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. La idempotencia (plan sin cambios) se comprueba
# además con `tofu plan -detailed-exitcode` sobre examples/complete en el job de CI.

# Aceptación (a mano, ver README): un backup bajo demanda de una base etiquetada BackupPlan termina, su copia
# cross-region aparece en el vault de DR y una prueba de restauración llega a COMPLETED.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = output.vault_arn != "" && output.dr_vault_arn != ""
    error_message = "Deben crearse el vault de origen y el de DR."
  }
}
