package main

import rego.v1

# Regla 5: todo bucket tiene un aws_s3_bucket_public_access_block asociado.
# Se resuelve con las referencias de la configuración (el id del bucket es desconocido en el plan),
# por lo que el bloqueo debe estar en el mismo módulo que el bucket.

# Direcciones base de los buckets cubiertos por un public access block, p. ej. "module.bucket.aws_s3_bucket.this".
protected_buckets contains addr if {
	some path, node
	walk(input.configuration, [path, node])
	some res in node.resources
	res.type == "aws_s3_bucket_public_access_block"
	some ref in res.expressions.bucket.references
	parts := split(ref, ".")
	count(parts) >= 2
	parts[0] == "aws_s3_bucket"
	name := regex.replace(parts[1], `\[.*\]$`, "")
	addr := concat(".", array.concat(module_path(path), ["aws_s3_bucket", name]))
}

# ["root_module","module_calls","a","module","module_calls","b","module"] -> ["module.a","module.b"]
module_path(path) := [sprintf("module.%s", [path[i + 1]]) |
	some i in numbers.range(0, count(path) - 1)
	path[i] == "module_calls"
]

deny contains msg if {
	some rc in surviving_changes
	rc.type == "aws_s3_bucket"
	not base_address(rc) in protected_buckets
	msg := sprintf("%s no tiene un aws_s3_bucket_public_access_block asociado en su módulo", [rc.address])
}
