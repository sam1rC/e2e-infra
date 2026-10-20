# saas-t2 / data

Capa `data` de SaaS T2: envuelve sin cambios la capa `data` de [`ecommerce-t2`](../../ecommerce-t2/data/README.md).

Mismas variables, salidas y rutas SSM que la capa de E-commerce T2 (ADR 0016, punto 6).

## Uso

Composición de referencia (equivale a `live/<env>/data` de la fase 10): [`../examples/complete/data`](../examples/complete/data).

- **Lee de SSM:** lo mismo que `ecommerce-t2/data`.
- **Publica en SSM:** lo mismo que `ecommerce-t2/data`.

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
| <a name="module_data"></a> [data](#module\_data) | ../../ecommerce-t2/data | n/a |

## Resources

No resources.

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

Las de [`ecommerce-t2/data`](../../ecommerce-t2/data/README.md).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
