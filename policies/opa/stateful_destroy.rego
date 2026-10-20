package main

import rego.v1

# Regla 1: prohibido destruir/reemplazar recursos con estado salvo etiqueta `allow-destroy`.
stateful_types := {
	"aws_rds_cluster",
	"aws_db_instance",
	"aws_dynamodb_table",
	"aws_s3_bucket",
	"aws_kms_key",
	"aws_cognito_user_pool",
	"aws_elasticache_replication_group",
	"aws_backup_vault",
}

deny contains msg if {
	not allow_destroy
	some rc in destroying_changes
	rc.type in stateful_types
	msg := sprintf("%s (%s) se destruiría o reemplazaría; añade la etiqueta 'allow-destroy' al PR solo si es intencional", [rc.address, rc.type])
}
