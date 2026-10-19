# saas-t1 / app-data

Capa `app-data` del app plane de SaaS T1: envuelve la capa `data` de [`ecommerce-t1`](../../ecommerce-t1/data/README.md).

Mismas variables, salidas y rutas SSM que la capa de E-commerce T1 (ADR 0016, punto 6). Valkey es opcional y está desactivado por defecto (`cache.enabled`).

## Uso

Composición de referencia (equivale a `live/<env>/app-data` de la fase 10): [`../examples/complete/app-data`](../examples/complete/app-data).

- **Lee de SSM:** lo mismo que `ecommerce-t1/data`.
- **Publica en SSM:** lo mismo que `ecommerce-t1/data`.

Visión general del blueprint, orden de despliegue y objetivos de resiliencia: [`../README.md`](../README.md). Composición entre capas: ADR [0016](../../../docs/adr/0016-blueprint-composition.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.30, < 7.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_data"></a> [data](#module\_data) | ../../ecommerce-t1/data | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aurora"></a> [aurora](#input\_aurora) | Aurora PostgreSQL provisionado: versión, clase (null = db.r7g.large en prod y db.t4g.medium en el resto), instancias (null = 2 en prod —writer y lector en AZ distintas— y 1 en el resto) y Database Insights (null = advanced en prod, standard en el resto). | <pre>object({<br/>    engine_version         = optional(string, "17.11")<br/>    instance_class         = optional(string)<br/>    instance_count         = optional(number)<br/>    database_insights_mode = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_cache"></a> [cache](#input\_cache) | ElastiCache Valkey con autenticación IAM (sin contraseñas). En SaaS T1 es opcional y está desactivado por defecto (enabled = true para activarlo). node\_type null = cache.m7g.large en prod y cache.t4g.micro en el resto; num\_cache\_clusters null = 2 en prod y 1 en el resto. | <pre>object({<br/>    enabled            = optional(bool, true)<br/>    engine_version     = optional(string, "8.2")<br/>    node_type          = optional(string)<br/>    num_cache_clusters = optional(number)<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
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

Las de [`ecommerce-t1/data`](../../ecommerce-t1/data/README.md).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
