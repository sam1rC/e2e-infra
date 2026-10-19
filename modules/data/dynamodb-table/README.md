# data/dynamodb-table

**Tabla DynamoDB** con SSE con la CMK del entorno, recuperación a un punto en el tiempo (PITR) siempre activa, protección de borrado fuera de dev y modo de pago por petición por defecto. Admite índices globales y locales, TTL, streams y Contributor Insights, y una variante multi-tenant (`tenant_partition_key`) para el aislamiento por partición de la fase 8.3.

## Uso

```hcl
module "orders" {
  source = "../../modules/data/dynamodb-table"

  project     = "acme"
  environment = "prod"
  name        = "orders"
  kms_key_arn = module.kms_data.key_arn # via_services: dynamodb.<región>.amazonaws.com

  tenant_partition_key = true
  hash_key             = "tenant_id"
  range_key            = "order_id"
  attributes           = { tenant_id = "S", order_id = "S", status = "S" }

  global_secondary_indexes = {
    by-status = { hash_key = "tenant_id", range_key = "status" }
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

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_dynamodb_contributor_insights.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_contributor_insights) | resource |
| [aws_dynamodb_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | Atributos clave de la tabla y de sus índices, como mapa nombre => tipo (S, N o B). Solo los que se usan como clave: DynamoDB rechaza atributos declarados que no estén en ninguna clave. | `map(string)` | n/a | yes |
| <a name="input_billing_mode"></a> [billing\_mode](#input\_billing\_mode) | PAY\_PER\_REQUEST (por defecto: sin planificar capacidad) o PROVISIONED (usa provisioned\_capacity). | `string` | `"PAY_PER_REQUEST"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Protección contra borrado. null = true en prod y en staging, false en dev. En prod no puede desactivarse. | `bool` | `null` | no |
| <a name="input_enable_contributor_insights"></a> [enable\_contributor\_insights](#input\_enable\_contributor\_insights) | Activa CloudWatch Contributor Insights en la tabla (claves más usadas y más limitadas). Tiene coste por evento. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_global_secondary_indexes"></a> [global\_secondary\_indexes](#input\_global\_secondary\_indexes) | Índices secundarios globales por nombre estable. Por defecto proyectan todos los atributos; con INCLUDE indica non\_key\_attributes. En modo PROVISIONED heredan la capacidad de la tabla. | <pre>map(object({<br/>    hash_key           = string<br/>    range_key          = optional(string)<br/>    projection_type    = optional(string, "ALL")<br/>    non_key_attributes = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_hash_key"></a> [hash\_key](#input\_hash\_key) | Clave de partición de la tabla. | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK del entorno que cifra la tabla (SSE con clave propia, no la gestionada por AWS). Su política debe autorizar a DynamoDB vía kms:ViaService. | `string` | n/a | yes |
| <a name="input_local_secondary_indexes"></a> [local\_secondary\_indexes](#input\_local\_secondary\_indexes) | Índices secundarios locales por nombre estable (misma clave de partición, otra de ordenación). Solo pueden definirse al crear la tabla; exigen range\_key. | <pre>map(object({<br/>    range_key          = string<br/>    projection_type    = optional(string, "ALL")<br/>    non_key_attributes = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre lógico de la tabla; el nombre real es <project>-<environment>-<name>. | `string` | n/a | yes |
| <a name="input_point_in_time_recovery_days"></a> [point\_in\_time\_recovery\_days](#input\_point\_in\_time\_recovery\_days) | Ventana de recuperación a un punto en el tiempo (1-35 días; PITR siempre activo). null = 35 en prod y 7 en el resto. | `number` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_provisioned_capacity"></a> [provisioned\_capacity](#input\_provisioned\_capacity) | Capacidad de lectura y escritura en modo PROVISIONED (la heredan los índices globales). Obligatoria con PROVISIONED y no permitida con PAY\_PER\_REQUEST. Sin autoescalado: para tráfico variable, usa PAY\_PER\_REQUEST. | <pre>object({<br/>    read  = number<br/>    write = number<br/>  })</pre> | `null` | no |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica el nombre y los ARN en SSM Parameter Store bajo /<project>/<env>/data/dynamodb/<name>/ para las capas consumidoras. | `bool` | `true` | no |
| <a name="input_range_key"></a> [range\_key](#input\_range\_key) | Clave de ordenación de la tabla (opcional). | `string` | `null` | no |
| <a name="input_stream_view_type"></a> [stream\_view\_type](#input\_stream\_view\_type) | Activa DynamoDB Streams con este contenido: KEYS\_ONLY, NEW\_IMAGE, OLD\_IMAGE o NEW\_AND\_OLD\_IMAGES. null = sin streams. | `string` | `null` | no |
| <a name="input_table_class"></a> [table\_class](#input\_table\_class) | STANDARD o STANDARD\_INFREQUENT\_ACCESS (almacenamiento más barato para tablas de acceso poco frecuente). | `string` | `"STANDARD"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_tenant_partition_key"></a> [tenant\_partition\_key](#input\_tenant\_partition\_key) | Tabla multi-tenant con aislamiento por partición: exige que hash\_key sea tenant\_id, de modo que las políticas IAM con dynamodb:LeadingKeys (fase 8.3) puedan limitar a cada tenant a sus filas. | `bool` | `false` | no |
| <a name="input_ttl_attribute"></a> [ttl\_attribute](#input\_ttl\_attribute) | Atributo con la fecha de expiración (epoch en segundos) para el TTL. null = sin TTL. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_iam_resource_arns"></a> [iam\_resource\_arns](#output\_iam\_resource\_arns) | Recursos para las políticas IAM de la aplicación: la tabla y todos sus índices. Con tenant\_partition\_key, combínalos con la condición dynamodb:LeadingKeys. |
| <a name="output_index_arns"></a> [index\_arns](#output\_index\_arns) | ARN de cada índice secundario (global o local), por nombre. |
| <a name="output_stream_arn"></a> [stream\_arn](#output\_stream\_arn) | ARN del stream; null si los streams están desactivados. |
| <a name="output_table_arn"></a> [table\_arn](#output\_table\_arn) | ARN de la tabla. |
| <a name="output_table_name"></a> [table\_name](#output\_table\_name) | Nombre real de la tabla. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Cifrado con CMK propia:** `server_side_encryption { enabled = true, kms_key_arn }` (sin `kms_key_arn` DynamoDB usaría una clave propiedad de AWS, sin trazabilidad). La política de la clave debe autorizar a DynamoDB por `kms:ViaService`.
- **PITR siempre activo**, con ventana configurable (`point_in_time_recovery_days`: 35 días en prod por defecto, 7 en el resto; mínimo 14 en prod).
- **`deletion_protection_enabled`:** activa por defecto fuera de dev y no desactivable en prod. El plan de conftest bloquea además cualquier reemplazo de la tabla salvo la etiqueta `allow-destroy`; cambiar la clave primaria o los índices locales fuerza reemplazo.
- **Facturación:** `PAY_PER_REQUEST` por defecto. `PROVISIONED` exige `provisioned_capacity` (la heredan los índices globales; sin autoescalado: para tráfico variable usa por petición) y se rechaza combinada con `PAY_PER_REQUEST`.
- **Índices:** mapas por nombre estable (`for_each` sobre claves, nunca por posición) y `attributes` declarado como mapa nombre → tipo; el módulo valida que cada clave esté declarada y que no sobren atributos (DynamoDB rechaza los no usados). Los índices globales usan `key_schema` (los `hash_key`/`range_key` dentro del índice están deprecados en el provider 6.x). Los índices locales solo pueden crearse junto con la tabla.
- **Multi-tenant:** `tenant_partition_key = true` exige `hash_key = "tenant_id"`, base para limitar a cada tenant a sus filas con `dynamodb:LeadingKeys` en la política IAM del rol de acceso del tenant (fase 8.3). La tabla lleva la etiqueta `TenantIsolation = partition-key` para auditar qué tablas deben aplicar esa condición. La salida `iam_resource_arns` devuelve la tabla y `…/index/*`, los dos recursos que esa política debe cubrir.
- **TTL, streams y Contributor Insights** opcionales. Contributor Insights tiene coste por evento; los streams con `NEW_AND_OLD_IMAGES` pueden contener datos de negocio: restringe quién los lee.
- **Transporte:** DynamoDB solo se alcanza por HTTPS; desde la VPC, mediante el endpoint de tipo gateway de `network/vpc-endpoints`.
- **SSM** (`/<project>/<env>/data/dynamodb/<name>/…`): `table_name`, `table_arn` y, con streams, `stream_arn`.

### Cómo se verificó

- 32 tests unitarios con `mock_provider` (on-demand/SSE-CMK/PITR, valores por defecto de dev/staging/prod, capacidad en PROVISIONED y sus índices, índices globales y locales con sus claves, TTL, streams, Contributor Insights, tabla multi-tenant con su etiqueta `TenantIsolation`, salidas IAM, SSM y 13 validaciones que deben fallar). Los dos ejemplos validan y su grafo es acíclico.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; el módulo no tiene data sources): 8 recursos en dos tablas (on-demand con índices, TTL y stream, y provisioned), esquema aceptado y políticas OPA de DynamoDB sin fallos (salvo las etiquetas de `default_tags`).
- **Pendiente en sandbox:** crear la tabla del ejemplo con la clave KMS, comprobar PITR (restaurar con el [runbook](../../../docs/runbooks/database-restore-pitr.md)) y que el servicio acepta `recovery_period_in_days` y `table_class` en la región elegida.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
