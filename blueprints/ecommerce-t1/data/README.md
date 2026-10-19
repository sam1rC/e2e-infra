# ecommerce-t1 / data

Capa de datos de E-commerce T1: Aurora PostgreSQL provisionado, ElastiCache Valkey con autenticación IAM y AWS Backup con copia a la región de DR y restore testing.

Aurora con 2 instancias en prod (writer + lector en AZ distintas) y Database Insights `advanced`; Valkey con 2 nodos en prod. AWS Backup `enterprise`: vault con bloqueo compliance en prod, copia diaria/mensual a un vault en la región de `aws.dr` (RPO 24 h ante la pérdida de la región) y restauración mensual de prueba de Aurora en la VPC del entorno.

## Uso

Composición de referencia (equivale a `live/<env>/data` de la fase 10): [`../examples/complete/data`](../examples/complete/data).

- **Lee de SSM:** `network` (VPC, subredes, AZ, SG de endpoints, topic de alarmas).
- **Publica en SSM:** `kms_key_arn`, `aurora/*` (módulo + `security_group_id`, `cluster_id`, `instance_count`), `valkey/*` (módulo + `security_group_id`, `iam_user_name`, `iam_user_arn`, `node_count`).

Visión general del blueprint, orden de despliegue y objetivos de resiliencia: [`../README.md`](../README.md). Composición entre capas: ADR [0016](../../../docs/adr/0016-blueprint-composition.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.30, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.68.0 |
| <a name="provider_aws.dr"></a> [aws.dr](#provider\_aws.dr) | 6.68.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_aurora"></a> [aurora](#module\_aurora) | ../../../modules/data/aurora-postgresql | n/a |
| <a name="module_backup"></a> [backup](#module\_backup) | ../../../modules/resilience/backup-plan | n/a |
| <a name="module_backup_kms"></a> [backup\_kms](#module\_backup\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_cache"></a> [cache](#module\_cache) | ../../../modules/data/elasticache-valkey | n/a |
| <a name="module_dr_backup"></a> [dr\_backup](#module\_dr\_backup) | ../../../modules/resilience/backup-plan | n/a |
| <a name="module_dr_backup_kms"></a> [dr\_backup\_kms](#module\_dr\_backup\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ../../../modules/foundation/kms-key | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_parameter.layer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_ingress_rule.endpoints_from_rotation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_region.dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameters_by_path.network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameters_by_path) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aurora"></a> [aurora](#input\_aurora) | Aurora PostgreSQL provisionado: versión, clase (null = db.r7g.large en prod y db.t4g.medium en el resto), instancias (null = 2 en prod —writer y lector en AZ distintas— y 1 en el resto) y Database Insights (null = advanced en prod, standard en el resto). | <pre>object({<br/>    engine_version         = optional(string, "17.11")<br/>    instance_class         = optional(string)<br/>    instance_count         = optional(number)<br/>    database_insights_mode = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_cache"></a> [cache](#input\_cache) | ElastiCache Valkey con autenticación IAM (sin contraseñas). enabled = false lo omite (SaaS T1 lo usa como opcional). node\_type null = cache.m7g.large en prod y cache.t4g.micro en el resto; num\_cache\_clusters null = 2 en prod y 1 en el resto. | <pre>object({<br/>    enabled            = optional(bool, true)<br/>    engine_version     = optional(string, "8.2")<br/>    node_type          = optional(string)<br/>    num_cache_clusters = optional(number)<br/>  })</pre> | `{}` | no |
| <a name="input_dr_copy"></a> [dr\_copy](#input\_dr\_copy) | Copia de los backups a la región de DR (provider aws.dr): RPO de 24 h ante la caída de la región (plan 9.1.1). null = true en prod y false en el resto. | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM. | `string` | n/a | yes |
| <a name="input_restore_testing"></a> [restore\_testing](#input\_restore\_testing) | Pruebas de restauración automáticas de AWS Backup (mensuales, restauran el último recovery point de Aurora y lo borran). null = true en prod y false en el resto. | `bool` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para los recursos (las obligatorias van en default\_tags del provider, en live/). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_app_secret_arn"></a> [app\_secret\_arn](#output\_app\_secret\_arn) | Secreto app\_runtime que lee la aplicación. |
| <a name="output_aurora_cluster_id"></a> [aurora\_cluster\_id](#output\_aurora\_cluster\_id) | Identificador del cluster Aurora. |
| <a name="output_aurora_security_group_id"></a> [aurora\_security\_group\_id](#output\_aurora\_security\_group\_id) | Security group de Aurora (la capa app añade la entrada desde las tareas). |
| <a name="output_aurora_writer_endpoint"></a> [aurora\_writer\_endpoint](#output\_aurora\_writer\_endpoint) | Endpoint del writer (privado). |
| <a name="output_backup_vault_names"></a> [backup\_vault\_names](#output\_backup\_vault\_names) | Vaults de AWS Backup: principal y de DR (null sin copia). |
| <a name="output_cache_replication_group_id"></a> [cache\_replication\_group\_id](#output\_cache\_replication\_group\_id) | Replication group de Valkey (host que firma el token IAM); null sin caché. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | CMK de datos. |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | Secreto maestro gestionado por RDS (solo administración y migraciones, p. ej. sql/). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- La aplicación nunca usa el usuario maestro: secreto gestionado por RDS para administración y secreto `app_runtime` con rotación multiusuario (la función vive en las subredes `app` y sale por el endpoint de Secrets Manager, al que esta capa le abre el 443).
- `rds.force_ssl`, cifrado con la CMK `data`, deletion protection fuera de dev y snapshot final en prod (módulos de datos).
- Valkey sin contraseñas: autenticación IAM con TLS; el usuario `default` está deshabilitado.
- Los SG de Aurora y Valkey se crean sin entradas: la capa `app` añade las suyas desde las tareas (ADR 0016).
- Vault lock en prod: **irreversible** tras `changeable_for_days = 3` (riesgo documentado en el plan). Las copias a DR usan una CMK propia de esa región.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
