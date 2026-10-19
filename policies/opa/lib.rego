package main

import rego.v1

# Cambios del plan (tofu show -json) que no son lecturas de data sources.
managed_changes contains rc if {
	some rc in input.resource_changes
	rc.mode == "managed"
}

# Cambios que dejan el recurso existiendo tras el apply (crear, actualizar o sin cambios).
surviving_changes contains rc if {
	some rc in managed_changes
	not "delete" in rc.change.actions
}

# Para destruir o reemplazar: "delete" aparece en delete, [delete,create] y [create,delete].
destroying_changes contains rc if {
	some rc in managed_changes
	"delete" in rc.change.actions
}

# Una etiqueta `allow-destroy` en el PR se traduce en `--data` con {"allow_destroy": true}.
default allow_destroy := false

allow_destroy := data.allow_destroy

# Dirección sin el índice final, p. ej. module.a.aws_s3_bucket.this[0] -> module.a.aws_s3_bucket.this
base_address(rc) := addr if {
	rc.module_address
	addr := sprintf("%s.%s.%s", [rc.module_address, rc.type, rc.name])
}

base_address(rc) := addr if {
	not rc.module_address
	addr := sprintf("%s.%s", [rc.type, rc.name])
}
