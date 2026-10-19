# s3-bucket

Bucket S3 con defaults seguros: Block Public Access, `BucketOwnerEnforced`, versionado, cifrado SSE-KMS con bucket key, política TLS ≥ 1.2 obligatoria y ciclo de vida de limpieza. Base de todos los buckets del catálogo.

## Uso

```hcl
module "bucket" {
  source = "../../modules/storage/s3-bucket"

  project     = "acme"
  environment = "dev"
  purpose     = "data"
  kms_key_arn = module.kms.key_arn
}
```

Más opciones (ciclo de vida, declaraciones de política, logging, Object Lock) en [`examples/complete`](examples/complete).

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
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_object_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_logging"></a> [access\_logging](#input\_access\_logging) | Logging de acceso al bucket (null = desactivado). El bucket destino debe permitir la entrega de logs de S3. | <pre>object({<br/>    target_bucket = string<br/>    target_prefix = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Nombre exacto del bucket. Si es null: <project>-<environment>-<purpose>-<account\_id>. | `string` | `null` | no |
| <a name="input_deny_unencrypted_uploads"></a> [deny\_unencrypted\_uploads](#input\_deny\_unencrypted\_uploads) | Añade una declaración que deniega PutObject con una cabecera de cifrado distinta a la configurada (las subidas sin cabecera siguen cifrándose por defecto). | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Permite borrar el bucket aunque contenga objetos. Solo para entornos efímeros. | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK con la que se cifra el bucket. Obligatorio si sse\_algorithm = aws:kms. | `string` | `null` | no |
| <a name="input_lifecycle_config"></a> [lifecycle\_config](#input\_lifecycle\_config) | Ciclo de vida del bucket. Los campos null desactivan esa acción. La limpieza de multipart incompletos y de versiones no actuales está activa por defecto. | <pre>object({<br/>    transition_to_ia_days           = optional(number)<br/>    transition_to_glacier_days      = optional(number)<br/>    expiration_days                 = optional(number)<br/>    noncurrent_expiration_days      = optional(number, 90)<br/>    noncurrent_versions_to_keep     = optional(number)<br/>    abort_incomplete_multipart_days = optional(number, 7)<br/>  })</pre> | `{}` | no |
| <a name="input_object_lock"></a> [object\_lock](#input\_object\_lock) | Object Lock con retención por defecto (null = desactivado). Solo se puede activar al crear el bucket. | <pre>object({<br/>    mode = optional(string, "GOVERNANCE")<br/>    days = number<br/>  })</pre> | `null` | no |
| <a name="input_policy_statements"></a> [policy\_statements](#input\_policy\_statements) | Declaraciones adicionales de la política del bucket. resource\_paths son sufijos sobre el ARN del bucket: "" = el bucket, "/*" = todos los objetos, "/prefijo/*" = un prefijo. | <pre>list(object({<br/>    sid            = string<br/>    effect         = optional(string, "Allow")<br/>    actions        = list(string)<br/>    resource_paths = optional(list(string), ["", "/*"])<br/>    principals = list(object({<br/>      type        = string<br/>      identifiers = list(string)<br/>    }))<br/>    conditions = optional(list(object({<br/>      test     = string<br/>      variable = string<br/>      values   = list(string)<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | Propósito del bucket; forma parte del nombre y condiciona las políticas. | `string` | n/a | yes |
| <a name="input_sse_algorithm"></a> [sse\_algorithm](#input\_sse\_algorithm) | Cifrado en reposo: aws:kms (CMK, por defecto) o AES256 (SSE-S3). AES256 solo donde el servicio escritor no admite KMS (logs de ALB/CloudFront estándar). | `string` | `"aws:kms"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales del bucket. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN del bucket. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Nombre (ID) del bucket. |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Nombre de dominio regional del bucket (para orígenes de CloudFront). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- Block Public Access en las cuatro opciones y `BucketOwnerEnforced` (sin ACLs). No existe forma de desactivarlos desde este módulo.
- Versionado siempre activo; las versiones no actuales caducan a los 90 días y los multipart incompletos a los 7 por defecto.
- La política deniega siempre `aws:SecureTransport = false` y `s3:TlsVersion < 1.2`.
- `deny_unencrypted_uploads` deniega solo cabeceras de cifrado *distintas* a la configurada (`StringNotEqualsIfExists`): las subidas sin cabecera se cifran con el cifrado por defecto, de modo que no rompe a servicios que no envían la cabecera.
- **Excepción documentada:** los logs estándar de ALB y CloudFront no pueden escribir en buckets con SSE-KMS. Para esos buckets usa `purpose = "logs"` con `sse_algorithm = "AES256"` y sin `kms_key_arn`.
- `force_destroy = false` por defecto; los buckets con datos de producción no se pueden borrar con objetos dentro.
- Object Lock solo puede activarse al crear el bucket; el modo `COMPLIANCE` es irreversible durante el periodo de retención.
- `access_logging` es opcional: el bucket destino debe permitir la entrega de logs de acceso de S3 (módulo con `purpose = "logs"`).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
