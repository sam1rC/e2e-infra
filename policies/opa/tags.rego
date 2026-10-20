package main

import rego.v1

# Regla 3: todo recurso etiquetable lleva las etiquetas obligatorias (en tags_all, que incluye default_tags).
required_tags := [
	"Project",
	"Environment",
	"Owner",
	"ManagedBy",
	"Blueprint",
	"CostCenter",
	"DataClassification",
]

# Solo se evalúan los recursos cuyo tags_all ya es conocido en el plan.
deny contains msg if {
	some rc in surviving_changes
	is_object(rc.change.after.tags_all)
	some tag in required_tags
	not tag in object.keys(rc.change.after.tags_all)
	msg := sprintf("%s no tiene la etiqueta obligatoria '%s'", [rc.address, tag])
}
