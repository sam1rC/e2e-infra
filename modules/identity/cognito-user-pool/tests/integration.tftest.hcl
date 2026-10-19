# Requiere credenciales de la cuenta sandbox. Corre solo en main/nightly:
#   tofu test -filter=tests/integration.tftest.hcl
# `tofu test` destruye todo al terminar. Coste: Cognito cobra por usuario activo al mes (sin usuarios, 0);
# el pool PLUS de examples/complete no tiene cuota fija. La comprobación de que un usuario no puede cambiar
# su custom:tenant_id está en tests/integration/tenant-isolation/cognito.sh.

run "apply_complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    name_suffix = formatdate("hhmmss", timestamp())
  }

  assert {
    condition     = can(regex("^https://cognito-idp\\.us-east-1\\.amazonaws\\.com/us-east-1_", output.issuer_url)) && length(output.client_ids) == 1
    error_message = "El pool y su app client deben crearse."
  }

  assert {
    condition     = can(regex("^https://acme-[0-9]+-tenants\\.auth\\.us-east-1\\.amazoncognito\\.com$", output.domain_url))
    error_message = "El dominio de managed login debe crearse."
  }
}
