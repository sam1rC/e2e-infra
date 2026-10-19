# compute/lambda-function

Función **Lambda** arm64 con tracing activo, logs JSON cifrados con KMS, rol de ejecución acotado, y VPC, concurrencia reservada, DLQ cifrada y firma de código opcionales.

## Uso

```hcl
module "orders" {
  source = "../../modules/compute/lambda-function"

  project     = "acme"
  environment = "prod"
  name        = "orders"
  kms_key_arn = module.kms_logs.key_arn # autoriza a logs.<región>.amazonaws.com

  runtime           = "python3.13"
  handler           = "app.handler"
  s3_bucket         = module.artifacts.bucket_id
  s3_key            = "orders/1.4.2.zip"
  s3_object_version = "3HL4kqtJlcpXroDTDmJ.rVAn.k3V9Gbh" # fija el código exacto

  vpc_config = {
    vpc_id     = module.vpc.vpc_id
    subnet_ids = module.vpc.subnet_ids["app"]
    egress_rules = {
      db = { description = "PostgreSQL", port = 5432, security_group_id = module.aurora.security_group_id }
    }
  }

  policies = {
    read-secret = data.aws_iam_policy_document.orders.json # acciones y recursos explícitos
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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.injected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_code_signing_config.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_code_signing_config) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_sqs_queue.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_application_log_level"></a> [application\_log\_level](#input\_application\_log\_level) | Nivel mínimo de los logs de la aplicación en formato JSON. | `string` | `"INFO"` | no |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | Arquitectura de la función: arm64 (Graviton, por defecto) o x86\_64. | `string` | `"arm64"` | no |
| <a name="input_code_signing"></a> [code\_signing](#input\_code\_signing) | Firma de código: perfiles de AWS Signer cuyos paquetes se aceptan (ARN de versión de perfil). Con policy Enforce, Lambda rechaza paquetes sin firma válida. Solo para paquetes zip. null = sin firma. | <pre>object({<br/>    signing_profile_version_arns = list(string)<br/>    policy                       = optional(string, "Enforce")<br/>  })</pre> | `null` | no |
| <a name="input_dlq_retention_days"></a> [dlq\_retention\_days](#input\_dlq\_retention\_days) | Días que la cola DLQ conserva los mensajes (1-14). | `number` | `14` | no |
| <a name="input_enable_dlq"></a> [enable\_dlq](#input\_enable\_dlq) | Crea una cola SQS cifrada con la CMK como destino de las invocaciones asíncronas fallidas (dead-letter). | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Variables de entorno NO secretas (se cifran con kms\_key\_arn). Los secretos se leen en ejecución desde Secrets Manager con una política inyectada: nunca van aquí. | `map(string)` | `{}` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Handler de la función (paquete zip); null con image\_uri. | `string` | `null` | no |
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | Imagen de contenedor por DIGEST (<repo>@sha256:<64 hex>). Alternativa al paquete zip. | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | CMK que cifra las variables de entorno, el log group y la cola DLQ. Su política debe autorizar a logs.<región>.amazonaws.com y, con DLQ, a SQS. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención del log group, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90. | `number` | `90` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Memoria en MB (128-10240). | `number` | `256` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre de la función; se llama <project>-<environment>-<name> (máx. 64 caracteres). | `string` | n/a | yes |
| <a name="input_permissions_boundary_arn"></a> [permissions\_boundary\_arn](#input\_permissions\_boundary\_arn) | ARN de una permissions boundary para el rol de ejecución. null = ninguna. | `string` | `null` | no |
| <a name="input_policies"></a> [policies](#input\_policies) | Políticas JSON en línea del rol de ejecución, por nombre estable, con acciones y recursos explícitos. El módulo solo añade lo imprescindible (logs, trazas, VPC, DLQ, KMS); nada más. | `map(string)` | `{}` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_reserved_concurrent_executions"></a> [reserved\_concurrent\_executions](#input\_reserved\_concurrent\_executions) | Concurrencia reservada de la función (limita y garantiza su capacidad). null = sin reserva. | `number` | `null` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Runtime de la función (paquete zip); null con image\_uri. Solo runtimes vigentes (se excluyen los obsoletos); revisa la lista oficial de runtimes de Lambda al actualizar el módulo. | `string` | `null` | no |
| <a name="input_s3_bucket"></a> [s3\_bucket](#input\_s3\_bucket) | Bucket con el paquete zip (el build es del pipeline de la aplicación). Usa s3\_bucket + s3\_key o image\_uri, no ambos. | `string` | `null` | no |
| <a name="input_s3_key"></a> [s3\_key](#input\_s3\_key) | Clave del paquete zip en s3\_bucket. | `string` | `null` | no |
| <a name="input_s3_object_version"></a> [s3\_object\_version](#input\_s3\_object\_version) | Versión del objeto S3 del paquete (el bucket está versionado): fija exactamente el código desplegado. | `string` | `null` | no |
| <a name="input_system_log_level"></a> [system\_log\_level](#input\_system\_log\_level) | Nivel mínimo de los logs del sistema de Lambda. | `string` | `"WARN"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_timeout_seconds"></a> [timeout\_seconds](#input\_timeout\_seconds) | Tiempo máximo de ejecución en segundos (1-900). | `number` | `10` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | Ejecuta la función dentro de la VPC (subredes app). El módulo crea un security group sin entrada y con la salida de egress\_rules. null = sin VPC. | <pre>object({<br/>    vpc_id     = string<br/>    subnet_ids = list(string)<br/>    egress_rules = optional(map(object({<br/>      description       = string<br/>      port              = number<br/>      protocol          = optional(string, "tcp")<br/>      security_group_id = optional(string)<br/>      prefix_list_id    = optional(string)<br/>      cidr_ipv4         = optional(string)<br/>    })), {})<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dlq_arn"></a> [dlq\_arn](#output\_dlq\_arn) | ARN de la cola de dead-letter (null si enable\_dlq es false). |
| <a name="output_function_arn"></a> [function\_arn](#output\_function\_arn) | ARN de la función. |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Nombre de la función. |
| <a name="output_invoke_arn"></a> [invoke\_arn](#output\_invoke\_arn) | ARN de invocación (para integraciones de API Gateway). |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Nombre del log group de la función. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN del rol de ejecución. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Nombre del rol de ejecución, para adjuntar políticas desde fuera del módulo. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group de la función (null si no está en la VPC). Añádelo a los orígenes permitidos de la base de datos o los endpoints. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **arm64 por defecto** (`architecture`), runtime validado contra una lista de runtimes **vigentes** (se excluyen los obsoletos; revisa la lista oficial de Lambda al actualizar el módulo) y paquete zip desde S3 (`s3_bucket` + `s3_key` + `s3_object_version`, que fija el código exacto) **o** imagen por **digest** (`image_uri`). El build lo hace el pipeline de la aplicación; el módulo valida que se indique un modo u otro, nunca ambos.
- **Rol de ejecución acotado, no `AWSLambdaBasicExecutionRole`.** El plan pedía esa política gestionada; esta permite `logs:*` sobre `"*"`. Aquí el rol recibe solo: `logs:CreateLogStream/PutLogEvents` sobre el log group de la función (que crea el módulo), `xray:PutTraceSegments/PutTelemetryRecords` (X-Ray no admite recursos concretos), `kms:Decrypt` sobre la CMK, y —solo si se piden— las acciones de interfaces de red para la VPC (tampoco admiten recursos concretos) y `sqs:SendMessage` + `kms:GenerateDataKey` para la DLQ. Todo lo demás entra por `policies` (JSON explícito, por nombre estable); nunca `*:*`. Admite una permissions boundary.
- **Trust policy con `aws:SourceAccount`** (protección contra *confused deputy*, como el resto de roles de servicio del catálogo): solo `lambda.amazonaws.com` actuando para esta cuenta asume el rol. No se añade `aws:SourceArn` porque la documentación de Lambda no garantiza esa clave al asumir roles de ejecución; la prueba de integración (`docs/test-plan-sandbox.md`, oleada 3) confirma que la función se crea e invoca con la condición.
- **Tracing y logs:** `tracing_config { mode = "Active" }` (nativo de Lambda; la instrumentación de código usa la capa ADOT/OpenTelemetry, no el SDK de X-Ray, que termina su soporte el 25-feb-2027) y `logging_config { log_format = "JSON" }` hacia un log group propio **cifrado con la CMK** y con retención (≥ 90 días en prod, validado).
- **Variables de entorno cifradas** con `kms_key_arn` y **sin secretos**: la función los lee en ejecución desde Secrets Manager con una política inyectada.
- **Opcional en VPC (`vpc_config`):** el módulo crea un security group **sin entrada** y con la salida de `egress_rules` (un destino exacto por regla: SG, lista de prefijos o CIDR); Terraform retira la salida abierta por defecto. Añade `security_group_id` a los orígenes permitidos de la base de datos y declara los endpoints de VPC que use la función.
- **Resiliencia opcional:** `reserved_concurrent_executions` (ojo: las cuentas nuevas tienen una cuota de 10 ejecuciones concurrentes y AWS exige dejar 10 sin reservar, así que cualquier reserva falla con `InvalidParameterValueException` hasta ampliar la cuota en Service Quotas; el ejemplo `complete` la deja en `null` por defecto), cola **SQS DLQ cifrada** con la CMK (`enable_dlq`; la política de la clave debe permitir a SQS, p. ej. `via_services = ["sqs.<región>.amazonaws.com"]`) y **firma de código** (`code_signing`, solo zip): con `policy = "Enforce"` Lambda rechaza paquetes sin firma válida de los perfiles de AWS Signer indicados.

### Cómo se verificó

- 27 tests unitarios con `mock_provider`: arm64/zip/KMS, tracing y logs JSON, paquete S3 y modo imagen, log group, concurrencia, variables de entorno, rol acotado y trust policy, políticas inyectadas y boundary, VPC con SG cerrado, DLQ, code signing y 9 validaciones que deben fallar. Los dos ejemplos validan; el completo sube un paquete mínimo a un bucket propio para poder aplicarse sin pipeline.
- **Pendiente en sandbox:** aplicar `examples/complete` e invocar la función; la entrega a la DLQ con la CMK; que la lista de runtimes coincide con la oficial en el momento de usar el módulo.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
