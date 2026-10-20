# integration/eventbridge-bus

**Bus de eventos personalizado** cifrado con CMK, con archivo para reproducir (replay) eventos y reglas por familia de eventos (`orders.*` en E-commerce, `usage.*` en SaaS) que entregan a **Data Firehose** (S3 no es destino directo de EventBridge). Cada regla tiene reintentos acotados y una **DLQ SQS cifrada**, y un único rol de mínimo privilegio.

Se combina con [`firehose-to-s3`](../firehose-to-s3), que crea el stream de destino: su `delivery_stream_arn` es el `firehose_arn` de cada regla.

## Uso

```hcl
module "events" {
  source = "../../modules/integration/eventbridge-bus"

  project     = "acme"
  environment = "prod"
  kms_key_arn = module.kms_events.key_arn # service_principals: events.amazonaws.com, sqs.amazonaws.com

  archive_retention_days = 90

  rules = {
    orders = {
      source_prefixes = ["orders."]
      firehose_arn    = module.firehose_orders.delivery_stream_arn
    }
  }

  target_kms_key_arns = [module.kms_events.key_arn]
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
| [aws_cloudwatch_event_archive.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_archive) | resource |
| [aws_cloudwatch_event_bus.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus) | resource |
| [aws_cloudwatch_event_bus_policy.publishers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus_policy) | resource |
| [aws_cloudwatch_event_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_role.events_to_firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.events_to_firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_sqs_queue.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.events_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.events_to_firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.publishers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_archive_retention_days"></a> [archive\_retention\_days](#input\_archive\_retention\_days) | Días que el archivo conserva los eventos para poder reproducirlos (replay). 0 desactiva el archivo. | `number` | `30` | no |
| <a name="input_dlq_retention_days"></a> [dlq\_retention\_days](#input\_dlq\_retention\_days) | Días que las DLQ conservan los eventos no entregados (1-14). | `number` | `14` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK que cifra el bus, el archivo y las colas DLQ. Su política debe autorizar a events.amazonaws.com (service\_principals de foundation/kms-key) y, para las DLQ, a sqs.amazonaws.com. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Nombre del bus. Si es null: <project>-<environment>-events. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica el nombre y el ARN del bus en SSM Parameter Store bajo /<project>/<env>/integration/ para las capas consumidoras. | `bool` | `true` | no |
| <a name="input_publisher_account_ids"></a> [publisher\_account\_ids](#input\_publisher\_account\_ids) | Cuentas AWS adicionales autorizadas a publicar en el bus (events:PutEvents), p. ej. cuentas de aplicación. Vacío = solo la propia cuenta. | `list(string)` | `[]` | no |
| <a name="input_retry_policy"></a> [retry\_policy](#input\_retry\_policy) | Reintentos de entrega a Firehose antes de enviar el evento a la DLQ. | <pre>object({<br/>    maximum_retry_attempts       = optional(number, 20)<br/>    maximum_event_age_in_seconds = optional(number, 3600)<br/>  })</pre> | `{}` | no |
| <a name="input_rules"></a> [rules](#input\_rules) | Reglas del bus por clave estable (p. ej. orders, usage), cada una hacia un delivery stream de Data Firehose (S3 no es destino directo de EventBridge). El patrón se indica con source\_prefixes y/o detail\_type\_prefixes (p. ej. ["orders."]) o con event\_pattern (JSON); no ambos. Cada regla tiene su DLQ SQS cifrada. | <pre>map(object({<br/>    firehose_arn         = string<br/>    description          = optional(string, "")<br/>    source_prefixes      = optional(list(string), [])<br/>    detail_type_prefixes = optional(list(string), [])<br/>    event_pattern        = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_target_kms_key_arns"></a> [target\_kms\_key\_arns](#input\_target\_kms\_key\_arns) | CMK de los delivery streams destino, si cifran con clave propia: el rol de EventBridge recibe kms:GenerateDataKey sobre ellas, con kms:ViaService de Firehose. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_archive_arn"></a> [archive\_arn](#output\_archive\_arn) | ARN del archivo para replay; null si el archivo está desactivado. |
| <a name="output_bus_arn"></a> [bus\_arn](#output\_bus\_arn) | ARN del bus. Úsalo en la política IAM de los publicadores (events:PutEvents). |
| <a name="output_bus_name"></a> [bus\_name](#output\_bus\_name) | Nombre del bus: es el valor de EventBusName en events:PutEvents. |
| <a name="output_dlq_arns"></a> [dlq\_arns](#output\_dlq\_arns) | ARN de la DLQ de cada regla, por clave. |
| <a name="output_dlq_names"></a> [dlq\_names](#output\_dlq\_names) | Nombre de la DLQ de cada regla, por clave (dimensión QueueName de las alarmas de mensajes visibles). |
| <a name="output_rule_arns"></a> [rule\_arns](#output\_rule\_arns) | ARN de cada regla, por clave. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Cifrado con CMK** del bus (`kms_key_identifier`), del archivo y de las colas DLQ. La política de la clave debe autorizar a `events.amazonaws.com` y `sqs.amazonaws.com` (`service_principals` de `foundation/kms-key`); si no, el bus o la entrega a la DLQ fallan al crearse o en su primer uso.
- **Archivo y replay:** `archive_retention_days` (30 por defecto; mínimo 7 en prod; 0 lo desactiva) conserva los eventos para reproducirlos tras un incidente o un fallo de entrega.
- **Un único destino por regla, y solo Firehose:** el rol de EventBridge solo tiene `firehose:PutRecord` y `firehose:PutRecordBatch` sobre los ARN declarados en `rules` (sin duplicados, sin `*`). Si los streams cifran con CMK propia, `target_kms_key_arns` añade `kms:GenerateDataKey`/`kms:Decrypt` sobre esas claves, solo vía Firehose.
- **Trust del rol sin confused deputy:** `events.amazonaws.com` con `aws:SourceAccount` y `aws:SourceArn` limitado a las reglas de este bus (ARN construido con los nombres para no crear ciclos).
- **Reintentos y DLQ por regla:** `retry_policy` (20 reintentos y 1 hora por defecto) y, agotados, el evento va a su cola `<bus>-<regla>-dlq`, cifrada, con retención de hasta 14 días y política que solo admite `sqs:SendMessage` de su propia regla y deniega el transporte sin TLS. **Alarma sobre la DLQ:** vigila `ApproximateNumberOfMessagesVisible` de cada cola (`dlq_names`) desde `observability/alarms` o desde el blueprint.
- **Quién puede publicar:** por defecto, solo la propia cuenta (IAM). `publisher_account_ids` añade una política de bus con `events:PutEvents` para esas cuentas; los publicadores locales necesitan `events:PutEvents` sobre `bus_arn` en su rol.
- **Patrones sin JSON a mano:** `source_prefixes` y `detail_type_prefixes` generan `{"source":[{"prefix":"orders."}]}`; para casos especiales, `event_pattern` (JSON válido) se usa tal cual. Una regla no puede mezclar ambos estilos.
- **SSM** (`/<project>/<env>/integration/…`): `event_bus_name` y `event_bus_arn`.

### Cómo se verificó

- 25 tests unitarios con `mock_provider` (bus cifrado, archivo, patrones generados, reintentos, DLQ cifradas con política TLS, rol acotado a los streams declarados y a sus claves, trust limitado a las reglas del bus, política de bus para otras cuentas, SSM y 9 validaciones que deben fallar). Los dos ejemplos validan y su grafo es acíclico.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; la cuenta sustituida por una constante en una copia): 15 recursos, esquema aceptado; patrones de eventos, `retry_policy` y `dead_letter_config` correctos en el plan JSON.
- **Pendiente en sandbox** (aceptación de la fase 7): un evento de prueba (`source = orders.test`) publicado en el bus aparece en S3 en menos del intervalo de búfer; un evento que Firehose no puede entregar acaba en la DLQ; el replay desde el archivo funciona; la política de la CMK con los principals de servicio indicados basta para el bus, el archivo y las DLQ.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
