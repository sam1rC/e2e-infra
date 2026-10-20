# Runbook — Verificar y restaurar la capa de datos (PITR y comprobaciones de la fase 6)

Aplica a `data/aurora-postgresql`, `data/rds-postgresql`, `data/elasticache-valkey` y `data/dynamodb-table`. Sirve para (a) la **aceptación de la fase 6** en sandbox y (b) una **restauración de prueba** periódica. Nunca restaures sobre el recurso original: crea siempre uno nuevo, valida y, si procede, redirige la aplicación.

> Los comandos usan `$AWS_REGION` y los identificadores que publica el módulo en SSM (`/<project>/<env>/data/...`). Las restauraciones usan los mismos subnet group, SG y CMK que el recurso original.

## 1. Comprobaciones de aceptación

### Sin contraseña maestra en el código ni en el estado
```bash
aws rds describe-db-clusters --db-cluster-identifier <cluster> \
  --query 'DBClusters[0].MasterUserSecret'          # o describe-db-instances para RDS
# El estado se descifra localmente con la clave de cifrado de OpenTofu (ADR 0002):
tofu state pull | grep -i -E 'password|secret_string' || echo "sin contraseñas en el estado"
```
Debe mostrar `SecretArn` y `KmsKeyId`, y el `grep` no debe encontrar ningún valor de contraseña (solo nombres de atributo como `manage_master_user_password`).

### Conexión sin TLS rechazada
Desde una tarea o un host de la VPC autorizado en el SG de la base:
```bash
psql "host=<endpoint> port=5432 dbname=app user=<usuario> sslmode=disable"   # debe fallar
psql "host=<endpoint> port=5432 dbname=app user=<usuario> sslmode=verify-full sslrootcert=<global-bundle.pem>"   # debe conectar
```
El primer intento falla con `no pg_hba.conf entry … no encryption` (efecto de `rds.force_ssl = 1`).

### Valkey: TLS e IAM
```bash
# sin TLS ni credenciales: debe rechazarse
valkey-cli -h <primary_endpoint> -p 6379 ping
# con TLS y token IAM (ver README del módulo para generar el token)
valkey-cli --tls -h <primary_endpoint> -p 6379 --user <usuario_iam> --pass "<token>" ping
```

### Security Hub sin hallazgos HIGH
```bash
aws securityhub get-findings --max-items 50 --filters '{
  "SeverityLabel":[{"Value":"HIGH","Comparison":"EQUALS"},{"Value":"CRITICAL","Comparison":"EQUALS"}],
  "RecordState":[{"Value":"ACTIVE","Comparison":"EQUALS"}],
  "ResourceType":[
    {"Value":"AwsRdsDbCluster","Comparison":"EQUALS"},{"Value":"AwsRdsDbInstance","Comparison":"EQUALS"},
    {"Value":"AwsElastiCacheReplicationGroup","Comparison":"EQUALS"},{"Value":"AwsDynamoDbTable","Comparison":"EQUALS"}]
}' --query 'Findings[].{Title:Title,Resource:Resources[0].Id}'
```
Debe devolver una lista vacía. Si el estándar de Security Hub aún no está habilitado en la cuenta, habilítalo antes (ver `foundation/account-baseline`).

## 2. Restauración de prueba (PITR)

### Aurora
```bash
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier <cluster> --db-cluster-identifier <cluster>-restore-test \
  --restore-type full-copy --use-latest-restorable-time \
  --db-subnet-group-name <subnet-group> --vpc-security-group-ids <sg-id> --kms-key-id <cmk-arn> \
  --enable-iam-database-authentication
aws rds create-db-instance --db-cluster-identifier <cluster>-restore-test \
  --db-instance-identifier <cluster>-restore-test-1 --engine aurora-postgresql --db-instance-class <clase>
aws rds wait db-instance-available --db-instance-identifier <cluster>-restore-test-1
```
Para un instante concreto, cambia `--use-latest-restorable-time` por `--restore-to-time 2026-10-05T12:00:00Z`.

### RDS PostgreSQL
```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier <instancia> --target-db-instance-identifier <instancia>-restore-test \
  --use-latest-restorable-time --db-subnet-group-name <subnet-group> --vpc-security-group-ids <sg-id> \
  --no-publicly-accessible --kms-key-id <cmk-arn>
aws rds wait db-instance-available --db-instance-identifier <instancia>-restore-test
```

### DynamoDB
```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name <tabla> --target-table-name <tabla>-restore-test --use-latest-restorable-time \
  --sse-specification-override Enabled=true,SSEType=KMS,KMSMasterKeyId=<cmk-arn>
aws dynamodb wait table-exists --table-name <tabla>-restore-test
```
La tabla restaurada **no hereda** PITR, TTL, streams ni alarmas: configúralos de nuevo si la vas a usar de verdad.

### Valkey
ElastiCache no tiene PITR: restaura desde una copia diaria (o la final) a un replication group nuevo:
```bash
aws elasticache describe-snapshots --replication-group-id <name>
aws elasticache create-replication-group --replication-group-id <name>-restore-test \
  --replication-group-description "restore test" --snapshot-name <copia> --engine valkey \
  --cache-node-type <tipo> --transit-encryption-enabled --at-rest-encryption-enabled --kms-key-id <cmk-arn> \
  --cache-subnet-group-name <subnet-group> --security-group-ids <sg-id> --user-group-ids <user-group-id>
```

## 3. Validar y limpiar
1. Conecta con un usuario de solo lectura, comprueba el recuento de filas/claves de una tabla conocida y la fecha del último dato.
2. Anota el **RPO real** (instante restaurado frente al solicitado) y el **RTO** (minutos hasta `available`) en el informe de resiliencia.
3. Borra los recursos `*-restore-test` (en Aurora, primero la instancia y luego el cluster, con `--skip-final-snapshot`; en prod, confirma dos veces el nombre antes de borrar).

El plan de AWS Backup de la fase 7.4 añade pruebas de restauración automáticas mensuales para los tiers que lo incluyan; este runbook cubre la comprobación manual de la aceptación y los simulacros ante incidentes.
