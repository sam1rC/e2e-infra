# data/aurora-postgresql

Cluster **Aurora PostgreSQL** (provisionado o Serverless v2) cifrado con la CMK del entorno, con contraseña maestra gestionada por RDS, autenticación IAM, TLS obligatorio, Database Insights, Enhanced Monitoring, secreto `app_runtime` con rotación y publicación de endpoints en SSM.

La aplicación **no usa el usuario maestro**: lee el secreto `app_runtime` (ver [`postgres-app-secret`](../postgres-app-secret)); el rol SQL lo crea el bootstrap de la fase 8.4.

## Uso

```hcl
module "aurora" {
  source = "../../modules/data/aurora-postgresql"

  project        = "acme"
  environment    = "prod"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.subnet_ids["data"]
  kms_key_arn    = module.kms_data.key_arn
  engine_version = "17.11"

  instance_class = "db.r7g.large"
  az_names       = ["us-east-1a", "us-east-1b"]

  allowed_security_group_ids = {
    app = module.ecs_service.security_group_id
  }

  database_insights_mode = "advanced"
  backup_plan            = "enterprise"

  app_secret_rotation = {
    subnet_ids                 = module.vpc.subnet_ids["app"]
    endpoint_security_group_id = module.vpc_endpoints.security_group_id
    semantic_version           = "<versión fijada>"
  }
}
```

Más opciones en [`examples/complete`](examples/complete).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.30, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.67.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_app_secret"></a> [app\_secret](#module\_app\_secret) | ../postgres-app-secret | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.postgresql](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_rds_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_rds_cluster_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_rds_cluster_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_parameter_group) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_ingress_rule.from_allowed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.monitoring_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_security_group_ids"></a> [allowed\_security\_group\_ids](#input\_allowed\_security\_group\_ids) | Security groups autorizados a conectar al puerto de PostgreSQL, como mapa nombre estable => ID. Un mapa (y no una lista) permite pasar IDs que aún no existen: las claves son conocidas al planificar. El SG de la base de datos no tiene reglas de salida. | `map(string)` | `{}` | no |
| <a name="input_app_secret_recovery_window_in_days"></a> [app\_secret\_recovery\_window\_in\_days](#input\_app\_secret\_recovery\_window\_in\_days) | Ventana de recuperación del secreto app\_runtime al borrarlo (7-30; 0 = borrado inmediato, solo fuera de prod). null = 30 en prod y 7 en el resto. La valida postgres-app-secret. | `number` | `null` | no |
| <a name="input_app_secret_rotation"></a> [app\_secret\_rotation](#input\_app\_secret\_rotation) | Rotación multiusuario del secreto app\_runtime (ver postgres-app-secret): subnet\_ids (capa app), endpoint\_security\_group\_id (SG del endpoint de Secrets Manager), automatically\_after\_days. Obligatoria en prod; null = solo el secreto vacío. | <pre>object({<br/>    subnet_ids                 = list(string)<br/>    endpoint_security_group_id = string<br/>    automatically_after_days   = optional(number, 30)<br/>  })</pre> | `null` | no |
| <a name="input_apply_immediately"></a> [apply\_immediately](#input\_apply\_immediately) | Aplica los cambios sin esperar a la ventana de mantenimiento (útil en dev; en prod mejor false). | `bool` | `false` | no |
| <a name="input_auto_minor_version_upgrade"></a> [auto\_minor\_version\_upgrade](#input\_auto\_minor\_version\_upgrade) | Aplica automáticamente las actualizaciones menores en la ventana de mantenimiento. | `bool` | `true` | no |
| <a name="input_az_names"></a> [az\_names](#input\_az\_names) | AZ donde se reparten las instancias (en orden: la primera aloja el writer). null = Aurora elige. Deben coincidir con las AZ de subnet\_ids. | `list(string)` | `null` | no |
| <a name="input_backup"></a> [backup](#input\_backup) | Copia de seguridad nativa (PITR). retention\_days null = 35 en prod y 7 en el resto (en prod, mínimo 14). Las ventanas no deben solaparse. Además, el cluster entra en el plan de AWS Backup por la etiqueta BackupPlan. | <pre>object({<br/>    retention_days     = optional(number)<br/>    window             = optional(string, "03:00-04:00")<br/>    maintenance_window = optional(string, "sun:05:00-sun:06:00")<br/>  })</pre> | `{}` | no |
| <a name="input_backup_plan"></a> [backup\_plan](#input\_backup\_plan) | Valor de la etiqueta BackupPlan que selecciona el cluster en el plan de AWS Backup (fase 7.4), p. ej. el tier. null = sin etiqueta. | `string` | `null` | no |
| <a name="input_capacity_mode"></a> [capacity\_mode](#input\_capacity\_mode) | provisioned (clase de instancia fija) o serverless\_v2 (ACU entre serverless\_v2.min\_capacity y max\_capacity). | `string` | `"provisioned"` | no |
| <a name="input_database_insights_mode"></a> [database\_insights\_mode](#input\_database\_insights\_mode) | CloudWatch Database Insights: standard (7 días, incluido) o advanced (15 meses, de pago; exige retención de 465 días). Sustituye a Performance Insights, retirado el 30-jun-2026. | `string` | `"standard"` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Base de datos inicial. | `string` | `"app"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Protección contra borrado. null = true en prod y en staging, false en dev. En prod no puede desactivarse. | `bool` | `null` | no |
| <a name="input_enable_http_endpoint"></a> [enable\_http\_endpoint](#input\_enable\_http\_endpoint) | Activa la RDS Data API (HTTP). Solo para el patrón sin conexiones persistentes (E-commerce T3 opción B); las llamadas se autorizan por IAM + secreto. | `bool` | `false` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Versión del motor Aurora PostgreSQL (p. ej. 17.11 o solo la mayor, 17). Verifica las disponibles con `aws rds describe-db-engine-versions --engine aurora-postgresql`. Con auto\_minor\_version\_upgrade el minor puede avanzar fuera de OpenTofu. La familia del parameter group se deduce de la versión mayor. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_final_snapshot_identifier"></a> [final\_snapshot\_identifier](#input\_final\_snapshot\_identifier) | Nombre de la instantánea final. null = <name>-final (si ya existe una con ese nombre, la destrucción falla: bórrala o cambia el nombre). | `string` | `null` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | Clase de instancia en modo provisioned (Graviton: db.t4g.medium en dev, db.r7g.large o mayor en prod). Se ignora en serverless\_v2 (db.serverless). | `string` | `"db.t4g.medium"` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Número de instancias (1 writer + lectores, repartidas en las AZ de az\_names). null = 2 en prod y 1 en el resto. | `number` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK del entorno: cifra el almacenamiento, el secreto maestro, el secreto de la aplicación, Database Insights y el log group. Su política debe autorizar a rds.amazonaws.com vía kms:ViaService, a Secrets Manager y a logs.<región>.amazonaws.com (service\_principals de foundation/kms-key). | `string` | n/a | yes |
| <a name="input_log_min_duration_statement"></a> [log\_min\_duration\_statement](#input\_log\_min\_duration\_statement) | Registra las consultas que duran más de este valor en milisegundos (-1 desactiva, 0 registra todas). | `number` | `1000` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención del log group de PostgreSQL, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90. | `number` | `90` | no |
| <a name="input_master_username"></a> [master\_username](#input\_master\_username) | Usuario maestro. Su contraseña la genera y rota RDS (secreto gestionado); es solo para administración y migraciones, la aplicación usa el secreto app\_runtime. | `string` | `"dbadmin"` | no |
| <a name="input_monitoring_interval"></a> [monitoring\_interval](#input\_monitoring\_interval) | Intervalo de Enhanced Monitoring en segundos (0 lo desactiva; en prod debe estar activo). | `number` | `60` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre del cluster. Si es null: <project>-<environment>-aurora. | `string` | `null` | no |
| <a name="input_port"></a> [port](#input\_port) | Puerto de PostgreSQL. | `number` | `5432` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_promotion_tier"></a> [promotion\_tier](#input\_promotion\_tier) | Prioridad de promoción a writer de las instancias lectoras (0-15; el writer inicial usa 0). | `number` | `1` | no |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica endpoints y ARNs en SSM Parameter Store bajo /<project>/<env>/data/<ssm\_namespace>/ para las capas consumidoras. | `bool` | `true` | no |
| <a name="input_serverless_v2"></a> [serverless\_v2](#input\_serverless\_v2) | Escalado de Aurora Serverless v2 (solo con capacity\_mode = serverless\_v2). min\_capacity = 0 activa la auto-pausa tras seconds\_until\_auto\_pause (300-86400) y exige una versión del motor que la soporte (verifícalo antes). | <pre>object({<br/>    min_capacity             = optional(number, 0.5)<br/>    max_capacity             = optional(number, 4)<br/>    seconds_until_auto_pause = optional(number)<br/>  })</pre> | `{}` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Omite la instantánea final al destruir. Solo permitido fuera de prod. | `bool` | `false` | no |
| <a name="input_ssm_namespace"></a> [ssm\_namespace](#input\_ssm\_namespace) | Segmento de la ruta SSM (evita colisiones si hay más de una base de datos en el entorno). | `string` | `"aurora"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subredes de la capa data (al menos 2, en AZ distintas) para el subnet group. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC donde se crea el security group de la base de datos. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_app_secret_arn"></a> [app\_secret\_arn](#output\_app\_secret\_arn) | ARN del secreto app\_runtime que leen las aplicaciones. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN del cluster. |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | Identificador del cluster. |
| <a name="output_cluster_resource_id"></a> [cluster\_resource\_id](#output\_cluster\_resource\_id) | ID de recurso del cluster (cluster-XXXX), el que usan los ARN de rds-db:connect. |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Base de datos inicial. |
| <a name="output_iam_auth_resource_arn_prefix"></a> [iam\_auth\_resource\_arn\_prefix](#output\_iam\_auth\_resource\_arn\_prefix) | Prefijo del ARN de rds-db:connect (arn:...:dbuser:<cluster\_resource\_id>): añade /<usuario\_sql> para dar acceso por IAM a un usuario concreto. |
| <a name="output_instance_ids"></a> [instance\_ids](#output\_instance\_ids) | Identificadores de las instancias, por clave (1 = writer inicial). |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Log group de los logs de PostgreSQL. |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | ARN del secreto maestro gestionado por RDS (solo administración y migraciones). |
| <a name="output_port"></a> [port](#output\_port) | Puerto de PostgreSQL. |
| <a name="output_reader_endpoint"></a> [reader\_endpoint](#output\_reader\_endpoint) | Endpoint de lectura (reparte entre las réplicas). |
| <a name="output_rotation_lambda_arn"></a> [rotation\_lambda\_arn](#output\_rotation\_lambda\_arn) | ARN de la función de rotación del secreto de la aplicación; null si no hay rotación. |
| <a name="output_rotation_security_group_id"></a> [rotation\_security\_group\_id](#output\_rotation\_security\_group\_id) | Security group de la función de rotación; null si no hay rotación. Autorízalo en el endpoint de Secrets Manager (allowed\_security\_group\_ids de vpc-endpoints). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group de la base de datos (sin reglas de salida). |
| <a name="output_writer_endpoint"></a> [writer\_endpoint](#output\_writer\_endpoint) | Endpoint del writer. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Cifrado en todo con una CMK:** almacenamiento, secreto maestro (`master_user_secret_kms_key_id`), secreto de la aplicación, Database Insights y log group. La política de la clave debe autorizar a RDS y Secrets Manager por `kms:ViaService` y a `logs.<región>.amazonaws.com` (ver `examples/complete`).
- **Sin contraseñas en el estado:** `manage_master_user_password = true`; no existe `master_password` en el código. `iam_database_authentication_enabled = true`; la salida `iam_auth_resource_arn_prefix` da el prefijo del ARN de `rds-db:connect` para el task role (`<prefijo>/<usuario_sql>`).
- **Usuario de aplicación ≠ maestro:** el secreto maestro es solo para administración y migraciones. `app_runtime` se crea vacío y con rotación multiusuario (obligatoria en prod).
- **TLS obligatorio y auditoría:** `rds.force_ssl = 1`, `log_connections`, `log_disconnections`, `log_min_duration_statement` configurable y `pgaudit` (`pgaudit.log = ddl,role`) precargado con `pg_stat_statements`. `shared_preload_libraries` es estático: se aplica con reinicio, y la extensión `pgaudit` se crea en la base con el bootstrap SQL.
- **Red cerrada:** subnet group de la capa `data`, `publicly_accessible = false` y un SG **sin reglas de salida** cuya entrada es TCP al puerto de PostgreSQL solo desde los SG de `allowed_security_group_ids` (mapa nombre → ID; nunca CIDR).
- **Protecciones de borrado y copias:** `deletion_protection` (por defecto activa fuera de dev; no puede desactivarse en prod), instantánea final siempre en prod, copias nativas de 35 días en prod (7 en el resto; mínimo 14 en prod), `copy_tags_to_snapshot`. Además, la etiqueta `BackupPlan` (`backup_plan`) incorpora el cluster al plan de AWS Backup de la fase 7.4. Si ya existe una instantánea `<name>-final`, la destrucción falla: bórrala o cambia `final_snapshot_identifier`.
- **Instancias:** en prod, mínimo 2 (writer y lector) repartidas por `az_names`; `promotion_tier` configurable para los lectores; `auto_minor_version_upgrade` activo (el minor puede avanzar fuera de OpenTofu: fija el minor y desactívalo si quieres control total). `allow_major_version_upgrade = false`: los saltos de versión mayor son decisión explícita.
- **Database Insights** (sustituye a Performance Insights, retirado el 30-jun-2026): `standard` (7 días, incluido) por defecto; `advanced` (15 meses, de pago) exige 465 días de retención, que el módulo fija en las instancias. **Enhanced Monitoring** con un rol propio acotado a la cuenta (equivalente a `AmazonRDSEnhancedMonitoringRole`, ADR 0012), obligatorio en prod.
- **Logs:** el log group `/aws/rds/cluster/<name>/postgresql` se crea antes con la CMK y retención (90 días mínimo en prod); si no, RDS lo crea sin cifrado ni caducidad.
- **Serverless v2:** `min_capacity = 0` activa la auto-pausa (`seconds_until_auto_pause`); exige una versión del motor que la soporte (verifícalo con `aws rds describe-db-engine-versions`). **Data API** (`enable_http_endpoint`) desactivada por defecto: solo para el patrón sin conexiones persistentes (E-commerce T3 opción B).
- **Versiones del motor:** `engine_version` es obligatorio y los ejemplos usan `17.11`, comprobada el 2026-10-05 con `describe-db-engine-versions` en us-east-1 (familia `aurora-postgresql17`, Serverless v2 de 0 a 384 ACU; la versión por defecto de AWS era 17.9 y ya existe la 18). Con `auto_minor_version_upgrade` el minor puede avanzar fuera de OpenTofu: fija solo la mayor (`17`) si no quieres planes con cambios tras cada actualización automática; la familia del parameter group se deduce de la versión mayor.
- **SSM** (`/<project>/<env>/data/aurora/…`): `writer_endpoint`, `reader_endpoint`, `port`, `database_name`, `cluster_arn`, `app_secret_arn` y `master_secret_arn`. Solo endpoints y ARN, nunca valores sensibles (ADR 0004).
- **Se llama a `../postgres-app-secret`:** los módulos de `modules/data` deben vendorizarse juntos (ADR 0005); no los consumas desde una fuente remota que copie solo este directorio.

### Cómo se verificó

- 40 tests unitarios con `mock_provider` (ventana de recuperación del secreto de la aplicación, cifrado/contraseña gestionada/IAM, parameter group, log group previo, valores por defecto de dev/staging/prod, claves estables de instancias y reparto por AZ, Serverless v2 con auto-pausa, Database Insights standard/advanced, SG por referencia sin CIDR, rol de monitorización, etiqueta `BackupPlan`, Data API, SSM, cableado del secreto y 13 validaciones que deben fallar). Los dos ejemplos validan y su grafo es acíclico.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; la cuenta sustituida por una constante en una copia, porque `aws_caller_identity` no resuelve offline): 24 recursos, esquema aceptado. El plan JSON pasa las políticas OPA de BD cifrada/no pública y de SG (solo fallan las etiquetas obligatorias, que añade `default_tags` en `live/`).
- **Pendiente en sandbox** (aceptación de la fase 6): Security Hub sin hallazgos HIGH, conexión sin TLS rechazada, `MasterUserSecret` visible y sin contraseña en `tofu state pull`, PITR de prueba ([runbook](../../../docs/runbooks/database-restore-pitr.md)), y comprobar que `database_insights_mode = advanced` se acepta con la retención fijada solo en las instancias (el provider también admite estos argumentos a nivel de cluster).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
