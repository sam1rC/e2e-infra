# Requiere la cuenta de management de una organización de PRUEBAS, una OU vacía y un correo único.
# OJO: crear una cuenta es real y no se deshace limpiamente: con close_on_deletion = false el destroy
# intenta sacarla de la organización, lo que AWS rechaza si la cuenta no tiene datos de pago propios; con
# true la cierra (queda suspendida 90 días). Ejecútalo solo en una organización de pruebas y cierra la
# cuenta a mano si el destroy falla. No se ejecuta en la sandbox actual (no pertenece a una organización).
#   tofu test -filter=tests/integration.tftest.hcl -var parent_id=ou-... -var email=...

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = can(regex("^[0-9]{12}$", output.account_id))
    error_message = "La cuenta debe crearse y devolver su ID."
  }
}
