package main

import rego.v1

# Regla 4: bases de datos cifradas y nunca públicas.
db_storage_types := {"aws_db_instance", "aws_rds_cluster"}

db_instance_types := {"aws_db_instance", "aws_rds_cluster_instance"}

deny contains msg if {
	some rc in surviving_changes
	rc.type in db_instance_types
	rc.change.after.publicly_accessible == true
	msg := sprintf("%s tiene publicly_accessible = true", [rc.address])
}

deny contains msg if {
	some rc in surviving_changes
	rc.type in db_storage_types
	not rc.change.after.storage_encrypted == true
	msg := sprintf("%s no tiene storage_encrypted = true", [rc.address])
}
