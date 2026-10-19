# integration/firehose-to-s3

**Delivery stream de Data Firehose hacia S3** con prefijo particionado por fecha, compresión GZIP, un evento por línea, cifrado SSE-KMS con CMK, búfer configurable y errores de entrega en un log group cifrado. Con `dynamic_partitioning` (SaaS) escribe cada evento bajo el prefijo de su tenant, extrayendo `tenant_id` del evento de EventBridge con JQ.

## Uso

```hcl
module "firehose" {
  source = "../../modules/integration/firehose-to-s3"

  project     = "acme"
  environment = "prod"
  name        = "usage"
  bucket_arn  = module.bucket_data.bucket_arn # SSE-KMS con la misma CMK
  kms_key_arn = module.kms_data.key_arn       # service_principals: logs.<región>.amazonaws.com

  prefix = "usage/"

  # SaaS: un prefijo por tenant
  buffer               = { size_mb = 64 }
  dynamic_partitioning = { key_name = "tenant_id", jq_query = ".detail.tenant_id" }
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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_stream.s3_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kinesis_firehose_delivery_stream.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_firehose_delivery_stream) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_arn"></a> [bucket\_arn](#input\_bucket\_arn) | ARN del bucket S3 de destino (p. ej. el módulo storage/s3-bucket con purpose = data), cifrado con SSE-KMS. | `string` | n/a | yes |
| <a name="input_buffer"></a> [buffer](#input\_buffer) | Búfer antes de escribir un objeto en S3: interval\_seconds (0-900) y size\_mb (1-128). Un evento tarda como máximo interval\_seconds en aparecer en S3. Con partición dinámica, size\_mb debe ser al menos 64. | <pre>object({<br/>    interval_seconds = optional(number, 60)<br/>    size_mb          = optional(number, 5)<br/>  })</pre> | `{}` | no |
| <a name="input_compression_format"></a> [compression\_format](#input\_compression\_format) | Compresión de los objetos: GZIP, ZIP, Snappy o HADOOP\_SNAPPY. | `string` | `"GZIP"` | no |
| <a name="input_dynamic_partitioning"></a> [dynamic\_partitioning](#input\_dynamic\_partitioning) | Partición dinámica por clave de cada evento (SaaS: un prefijo por tenant). key\_name es el nombre de la partición y jq\_query la expresión JQ sobre el evento de EventBridge (p. ej. .detail.tenant\_id). Los eventos sin esa clave van al prefijo de errores. null = solo partición por fecha. | <pre>object({<br/>    key_name = string<br/>    jq_query = string<br/>  })</pre> | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_error_prefix"></a> [error\_prefix](#input\_error\_prefix) | Prefijo de los objetos que Firehose no puede entregar o procesar (sin barra inicial; con barra final). Se le añade el tipo de error y la fecha. | `string` | `"errors/"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK que cifra los objetos en S3, el stream y el log group. Su política debe autorizar a logs.<región>.amazonaws.com (service\_principals de foundation/kms-key); el rol de Firehose recibe los permisos por su cuenta. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención del log group de errores de entrega, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90. | `number` | `90` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre lógico del stream; el real es <project>-<environment>-<name>. | `string` | `"events"` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefijo base de los objetos (sin barra inicial; con barra final). Se le añade la partición por fecha !{timestamp:yyyy/MM/dd}/ y, con partición dinámica, la clave del tenant. | `string` | `"events/"` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica el nombre y el ARN del stream en SSM Parameter Store bajo /<project>/<env>/integration/ para las capas consumidoras. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_delivery_stream_arn"></a> [delivery\_stream\_arn](#output\_delivery\_stream\_arn) | ARN del delivery stream: es el firehose\_arn de las reglas de eventbridge-bus. |
| <a name="output_delivery_stream_name"></a> [delivery\_stream\_name](#output\_delivery\_stream\_name) | Nombre del delivery stream (dimensión DeliveryStreamName de las métricas de CloudWatch). |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Log group de los errores de entrega. |
| <a name="output_object_prefix"></a> [object\_prefix](#output\_object\_prefix) | Prefijo de los objetos en S3 (con las expresiones de partición de Firehose). |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | Rol de entrega del stream. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Cifrado en todo con una CMK:** objetos en S3 (`kms_key_arn`), búfer del stream (`server_side_encryption` con `CUSTOMER_MANAGED_CMK`, válido porque el stream es DirectPut) y log group de errores. El rol solo puede usar la clave a través de S3 y Firehose (`kms:ViaService`).
- **Rol de mínimo privilegio y trust sin confused deputy:** acciones de S3 explícitas sobre el bucket y sus objetos, `kms:Decrypt`/`kms:GenerateDataKey` sobre la CMK, `logs:PutLogEvents` solo sobre el stream `S3Delivery` del log group; ninguna sentencia usa `Resource = *`. El trust exige `aws:SourceAccount` y `aws:SourceArn` del propio stream (ARN construido con el nombre para evitar un ciclo rol ↔ stream).
- **Un evento por línea:** el procesador `AppendDelimiterToRecord` separa los eventos con `\n`, de modo que los objetos GZIP se pueden consultar con Athena sin postprocesado.
- **Prefijos:** `<prefix>!{timestamp:yyyy/MM/dd}/` para los datos y `<error_prefix>!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/` para lo que no se puede entregar o procesar (los eventos sin la clave de partición van aquí, no se pierden).
- **Partición dinámica por tenant (SaaS):** el procesador `MetadataExtraction` (JQ-1.6) extrae `{<key_name>: <jq_query>}` y el prefijo pasa a `<prefix>!{partitionKeyFromQuery:<key_name>}/<fecha>/`. Firehose exige un búfer de al menos 64 MB con partición dinámica (validado). El prefijo por tenant es una separación de datos, no un control de acceso: el aislamiento por tenant en S3 se hace con políticas IAM/ABAC de la fase 8.
- **Tiempo hasta S3:** un evento aparece en S3 como mucho tras `buffer.interval_seconds` (60 s por defecto) o al llenarse `buffer.size_mb`.
- **SSM** (`/<project>/<env>/integration/…`): `firehose_stream_name` y `firehose_stream_arn`.
- **Bucket con `deny_unencrypted_uploads`:** compatible, porque Firehose escribe con SSE-KMS con la CMK indicada.

### Cómo se verificó

- 18 tests unitarios con `mock_provider` (destino S3 con CMK/GZIP/prefijos, cifrado del stream, log group cifrado, procesadores con y sin partición dinámica, trust y política del rol sin comodines, SSM y 9 validaciones que deben fallar). Los dos ejemplos validan y su grafo es acíclico.
- **Plan real offline** contra el provider 6.67.0 (misma técnica que `eventbridge-bus`): 7 recursos, esquema aceptado; prefijos, `dynamic_partitioning_configuration` y parámetros de los procesadores correctos en el plan JSON.
- **Pendiente en sandbox:** un evento con `detail.tenant_id` aparece en `<prefix><tenant>/aaaa/mm/dd/`; un evento sin `tenant_id` va al prefijo de errores; Firehose acepta la combinación SSE con CMK + entrega SSE-KMS con los permisos de KMS indicados (los de SSE no se han verificado contra el servicio).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
