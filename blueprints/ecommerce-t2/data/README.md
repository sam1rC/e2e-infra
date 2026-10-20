# ecommerce-t2 / data

Capa de datos de E-commerce T2: RDS PostgreSQL (Multi-AZ en prod) y AWS Backup con vault lock.

Clase `db.t4g.micro` fuera de prod y `db.m7g.large` en prod (variable); Database Insights `standard`. AWS Backup `growth`: diaria, mensual y continua (PITR) en prod; vault bloqueado en prod.

## Uso

Composición de referencia (equivale a `live/<env>/data` de la fase 10): [`../examples/complete/data`](../examples/complete/data).

- **Lee de SSM:** `network`.
- **Publica en SSM:** `kms_key_arn`, `postgres/*` (módulo + `security_group_id`, `instance_id`).

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

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_backup"></a> [backup](#module\_backup) | ../../../modules/resilience/backup-plan | n/a |
| <a name="module_backup_kms"></a> [backup\_kms](#module\_backup\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_postgres"></a> [postgres](#module\_postgres) | ../../../modules/data/rds-postgresql | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_parameter.layer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_ingress_rule.endpoints_from_rotation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameters_by_path.network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameters_by_path) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Versión de PostgreSQL (comprobar las disponibles con `aws rds describe-db-engine-versions --engine postgres`). | `string` | `"17.11"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | Clase de la instancia. null = db.m7g.large en prod y db.t4g.micro en el resto (la más barata con Graviton). | `string` | `null` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Standby síncrono en otra AZ. null = true en prod y false en el resto (el blueprint T2 es Multi-AZ en prod). | `bool` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM. | `string` | n/a | yes |
| <a name="input_storage"></a> [storage](#input\_storage) | Almacenamiento gp3: allocated\_gb inicial y max\_allocated\_gb del autoescalado (0 lo desactiva). | <pre>object({<br/>    allocated_gb     = optional(number, 20)<br/>    max_allocated_gb = optional(number, 100)<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para los recursos (las obligatorias van en default\_tags del provider, en live/). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_app_secret_arn"></a> [app\_secret\_arn](#output\_app\_secret\_arn) | Secreto app\_runtime que lee la aplicación. |
| <a name="output_backup_vault_name"></a> [backup\_vault\_name](#output\_backup\_vault\_name) | Vault de AWS Backup del entorno. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | Endpoint de la instancia (privado). |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | Identificador de la instancia PostgreSQL. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | CMK de datos. |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | Secreto maestro gestionado por RDS (solo administración y migraciones, p. ej. sql/). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group de la base de datos (la capa app añade la entrada desde las tareas). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- La aplicación nunca usa el usuario maestro: secreto gestionado por RDS para administración y secreto `app_runtime` con rotación multiusuario (la función sale por el endpoint de Secrets Manager, al que esta capa le abre el 443).
- `rds.force_ssl`, cifrado con la CMK `data`, deletion protection fuera de dev, snapshot final en prod.
- El SG de la base de datos se crea sin entradas: la capa `app` añade la suya desde las tareas (ADR 0016).
- Vault lock en prod: **irreversible** tras `changeable_for_days = 3`.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
