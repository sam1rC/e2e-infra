# data/rds-postgresql

Instancia **RDS PostgreSQL** (gp3, Graviton, Multi-AZ en prod) con las mismas garantías de seguridad que [`aurora-postgresql`](../aurora-postgresql): CMK, contraseña maestra gestionada por RDS, autenticación IAM, TLS obligatorio, Database Insights, Enhanced Monitoring, secreto `app_runtime` con rotación y publicación en SSM.

## Uso

```hcl
module "rds" {
  source = "../../modules/data/rds-postgresql"

  project        = "acme"
  environment    = "prod"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.subnet_ids["data"]
  kms_key_arn    = module.kms_data.key_arn
  engine_version = "17.11"

  instance_class = "db.m7g.large"
  storage        = { allocated_gb = 100, max_allocated_gb = 500 }

  allowed_security_group_ids = {
    app = module.ecs_service.security_group_id
  }

  backup_plan = "growth"

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
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
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
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | AZ de la instancia primaria (solo si multi\_az = false o para fijar la preferida). null = RDS elige. | `string` | `null` | no |
| <a name="input_backup"></a> [backup](#input\_backup) | Copia de seguridad nativa (PITR). retention\_days null = 35 en prod y 7 en el resto (en prod, mínimo 14). Las ventanas no deben solaparse. Además, la instancia entra en el plan de AWS Backup por la etiqueta BackupPlan. | <pre>object({<br/>    retention_days     = optional(number)<br/>    window             = optional(string, "03:00-04:00")<br/>    maintenance_window = optional(string, "sun:05:00-sun:06:00")<br/>  })</pre> | `{}` | no |
| <a name="input_backup_plan"></a> [backup\_plan](#input\_backup\_plan) | Valor de la etiqueta BackupPlan que selecciona la instancia en el plan de AWS Backup (fase 7.4), p. ej. el tier. null = sin etiqueta. | `string` | `null` | no |
| <a name="input_database_insights_mode"></a> [database\_insights\_mode](#input\_database\_insights\_mode) | CloudWatch Database Insights: standard (7 días, incluido) o advanced (15 meses, de pago; exige retención de 465 días). Sustituye a Performance Insights, retirado el 30-jun-2026. | `string` | `"standard"` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Base de datos inicial. | `string` | `"app"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Protección contra borrado. null = true en prod y en staging, false en dev. En prod no puede desactivarse. | `bool` | `null` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Versión del motor PostgreSQL (p. ej. 17.11 o solo la mayor, 17). Verifica las disponibles con `aws rds describe-db-engine-versions --engine postgres`. Con auto\_minor\_version\_upgrade el minor puede avanzar fuera de OpenTofu. La familia del parameter group se deduce de la versión mayor. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_final_snapshot_identifier"></a> [final\_snapshot\_identifier](#input\_final\_snapshot\_identifier) | Nombre de la instantánea final. null = <name>-final (si ya existe una con ese nombre, la destrucción falla: bórrala o cambia el nombre). | `string` | `null` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | Clase de instancia (Graviton: db.t4g.medium en dev, db.m7g.large o mayor en prod). | `string` | `"db.t4g.medium"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK del entorno: cifra el almacenamiento, el secreto maestro, el secreto de la aplicación, Database Insights y el log group. Su política debe autorizar a rds.amazonaws.com vía kms:ViaService, a Secrets Manager y a logs.<región>.amazonaws.com (service\_principals de foundation/kms-key). | `string` | n/a | yes |
| <a name="input_log_min_duration_statement"></a> [log\_min\_duration\_statement](#input\_log\_min\_duration\_statement) | Registra las consultas que duran más de este valor en milisegundos (-1 desactiva, 0 registra todas). | `number` | `1000` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención del log group de PostgreSQL, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90. | `number` | `90` | no |
| <a name="input_master_username"></a> [master\_username](#input\_master\_username) | Usuario maestro. Su contraseña la genera y rota RDS (secreto gestionado); es solo para administración y migraciones, la aplicación usa el secreto app\_runtime. | `string` | `"dbadmin"` | no |
| <a name="input_monitoring_interval"></a> [monitoring\_interval](#input\_monitoring\_interval) | Intervalo de Enhanced Monitoring en segundos (0 lo desactiva; en prod debe estar activo). | `number` | `60` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Standby síncrono en otra AZ. null = true en prod y false en el resto; en prod no puede ser false. | `bool` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre de la instancia. Si es null: <project>-<environment>-postgres. | `string` | `null` | no |
| <a name="input_port"></a> [port](#input\_port) | Puerto de PostgreSQL. | `number` | `5432` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica endpoints y ARNs en SSM Parameter Store bajo /<project>/<env>/data/<ssm\_namespace>/ para las capas consumidoras. | `bool` | `true` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Omite la instantánea final al destruir. Solo permitido fuera de prod. | `bool` | `false` | no |
| <a name="input_ssm_namespace"></a> [ssm\_namespace](#input\_ssm\_namespace) | Segmento de la ruta SSM (evita colisiones si hay más de una base de datos en el entorno). | `string` | `"postgres"` | no |
| <a name="input_storage"></a> [storage](#input\_storage) | Almacenamiento gp3: allocated\_gb inicial (mínimo 20) y max\_allocated\_gb para el autoescalado (0 lo desactiva). Reducir allocated\_gb fuerza el reemplazo de la instancia (RDS no encoge discos). | <pre>object({<br/>    allocated_gb     = optional(number, 20)<br/>    max_allocated_gb = optional(number, 100)<br/>  })</pre> | `{}` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subredes de la capa data (al menos 2, en AZ distintas) para el subnet group. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC donde se crea el security group de la base de datos. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_app_secret_arn"></a> [app\_secret\_arn](#output\_app\_secret\_arn) | ARN del secreto app\_runtime que leen las aplicaciones. |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Base de datos inicial. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | Nombre DNS de la instancia (sin puerto). |
| <a name="output_iam_auth_resource_arn_prefix"></a> [iam\_auth\_resource\_arn\_prefix](#output\_iam\_auth\_resource\_arn\_prefix) | Prefijo del ARN de rds-db:connect (arn:...:dbuser:<resource\_id>): añade /<usuario\_sql> para dar acceso por IAM a un usuario concreto. |
| <a name="output_instance_arn"></a> [instance\_arn](#output\_instance\_arn) | ARN de la instancia. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | Identificador de la instancia. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Log group de los logs de PostgreSQL. |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | ARN del secreto maestro gestionado por RDS (solo administración y migraciones). |
| <a name="output_port"></a> [port](#output\_port) | Puerto de PostgreSQL. |
| <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id) | ID de recurso de la instancia (db-XXXX), el que usan los ARN de rds-db:connect. |
| <a name="output_rotation_lambda_arn"></a> [rotation\_lambda\_arn](#output\_rotation\_lambda\_arn) | ARN de la función de rotación del secreto de la aplicación; null si no hay rotación. |
| <a name="output_rotation_security_group_id"></a> [rotation\_security\_group\_id](#output\_rotation\_security\_group\_id) | Security group de la función de rotación; null si no hay rotación. Autorízalo en el endpoint de Secrets Manager (allowed\_security\_group\_ids de vpc-endpoints). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group de la base de datos (sin reglas de salida). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

Todo lo de [`aurora-postgresql`](../aurora-postgresql#decisiones-de-seguridad) aplica igual (CMK, contraseña gestionada, IAM, `rds.force_ssl`, `pgaudit`, SG sin salida con entrada por referencia, Database Insights, log group previo con CMK, SSM, secreto de aplicación con rotación obligatoria en prod). Diferencias propias de `aws_db_instance`:

- **Multi-AZ:** `multi_az = null` ⇒ `true` en prod y `false` en el resto; en prod no puede ser `false`. Con Multi-AZ no se fija `availability_zone` (RDS reparte primaria y standby); en Single-AZ puede fijarse con `availability_zone`.
- **Almacenamiento gp3** con autoescalado: `storage.allocated_gb` (mínimo 20) y `storage.max_allocated_gb` (por defecto 100; `0` lo desactiva). RDS no encoge discos: reducir `allocated_gb` fuerza el reemplazo de la instancia, y el plan de conftest bloquea ese reemplazo salvo la etiqueta `allow-destroy`.
- **Una sola instancia:** no hay lectores ni `promotion_tier`; para réplicas de lectura o alta disponibilidad con lectores usa Aurora.
- **Logs:** `/aws/rds/instance/<name>/postgresql` (solo el log de PostgreSQL).
- **SSM** (`/<project>/<env>/data/postgres/…`): `endpoint`, `port`, `database_name`, `instance_arn`, `app_secret_arn` y `master_secret_arn`.
- **Se llama a `../postgres-app-secret`:** vendoriza los módulos de `modules/data` juntos (ADR 0005).

### Cómo se verificó

- 35 tests unitarios con `mock_provider` (ventana de recuperación del secreto de la aplicación, cifrado/contraseña gestionada/IAM, gp3 y autoescalado configurable, Multi-AZ por entorno, AZ fija en Single-AZ, parameter group, valores por defecto de dev/staging/prod, Database Insights, SG por referencia, rol de monitorización, etiqueta `BackupPlan`, SSM y 13 validaciones que deben fallar). Los dos ejemplos validan y su grafo es acíclico.
- **Plan real offline** contra el provider 6.67.0 (misma técnica que Aurora): 21 recursos, esquema aceptado y políticas OPA de BD sin fallos (salvo las etiquetas de `default_tags`).
- **Pendiente en sandbox:** la misma aceptación que Aurora (Security Hub, TLS, secreto maestro, PITR con el [runbook](../../../docs/runbooks/database-restore-pitr.md)).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
