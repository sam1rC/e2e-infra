# cloudfront-static-site

Sitio estático (SPA) servido por CloudFront desde un bucket S3 privado con OAC y SSE-KMS, con origen de API opcional protegido por cabecera de verificación, WAF opcional y alias en Route 53.

## Uso

```hcl
# Instanciar con el provider de us-east-1
module "site" {
  source    = "../../modules/edge/cloudfront-static-site"
  providers = { aws = aws.us_east_1 }

  project                    = "acme"
  environment                = "prod"
  domain_names               = ["www.cliente.com"]
  acm_certificate_arn        = module.certificate_viewer.certificate_arn
  web_acl_arn                = module.waf.web_acl_arn
  response_headers_policy_id = module.security_headers.policy_id
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
| <a name="module_bucket"></a> [bucket](#module\_bucket) | ../../storage/s3-bucket | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ../../foundation/kms-key | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_function.spa_routing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_function) | resource |
| [aws_cloudfront_origin_access_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_cloudwatch_log_delivery.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery_destination.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_source.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |
| [aws_route53_record.alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_cloudfront_cache_policy.caching_disabled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_cache_policy.caching_optimized](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_origin_request_policy.all_viewer_except_host](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_origin_request_policy) | data source |
| [aws_iam_policy_document.key_cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_logs_enabled"></a> [access\_logs\_enabled](#input\_access\_logs\_enabled) | Activa los logs de acceso. Indícalo (true) cuando log\_bucket\_arn se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crean los recursos de logging. null = activado si log\_bucket\_arn no es null. | `bool` | `null` | no |
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | Certificado ACM del viewer (debe estar en us-east-1 y emitido). | `string` | n/a | yes |
| <a name="input_api"></a> [api](#input\_api) | Origen de API opcional (p. ej. API Gateway) que se sirve en path\_pattern sin caché. domain\_name es el dominio del endpoint, sin esquema. | <pre>object({<br/>    domain_name  = string<br/>    origin_path  = optional(string, "")<br/>    path_pattern = optional(string, "/api/*")<br/>  })</pre> | `null` | no |
| <a name="input_api_origin_verify_secret"></a> [api\_origin\_verify\_secret](#input\_api\_origin\_verify\_secret) | Valor de la cabecera x-origin-verify que CloudFront añade al origen de API; el origen (WAF regional o middleware) bloquea lo que no la lleve, para que la API no se pueda llamar saltándose CloudFront/WAF. El secreto queda en el estado (cifrado) y es legible en la configuración de CloudFront: es un token de verificación rotable, no una credencial de datos (ADR 0010). | `string` | `null` | no |
| <a name="input_domain_names"></a> [domain\_names](#input\_domain\_names) | Nombres de dominio públicos (alias) de la distribución. El certificado debe cubrirlos. | `list(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Permite borrar el bucket aunque contenga objetos. Solo para entornos efímeros. | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | CMK del bucket. Si es null el módulo crea una propia, con permiso de lectura para las distribuciones de CloudFront de la cuenta. Si aportas la tuya, su key policy debe permitir a cloudfront.amazonaws.com kms:Decrypt/GenerateDataKey* (con aws:SourceArn de la distribución). | `string` | `null` | no |
| <a name="input_log_bucket_arn"></a> [log\_bucket\_arn](#input\_log\_bucket\_arn) | Bucket S3 para los logs de acceso (logging estándar v2, sin ACL). La entrega escribe en AWSLogs/<cuenta>/CloudFront/<log\_prefix>/...: su política debe permitir s3:PutObject en AWSLogs/<cuenta>/CloudFront/* a delivery.logs.amazonaws.com con aws:SourceAccount y aws:SourceArn del delivery source <project>-<environment>-cloudfront (si falta, CloudWatch Logs añade su propia declaración y el siguiente apply la borraría). null = sin logs. | `string` | `null` | no |
| <a name="input_log_prefix"></a> [log\_prefix](#input\_log\_prefix) | Prefijo de los logs dentro del bucket. | `string` | `"cloudfront"` | no |
| <a name="input_price_class"></a> [price\_class](#input\_price\_class) | Clase de precio de la distribución. | `string` | `"PriceClass_100"` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_response_headers_policy_id"></a> [response\_headers\_policy\_id](#input\_response\_headers\_policy\_id) | ID de la response headers policy de seguridad (módulo security-headers). | `string` | n/a | yes |
| <a name="input_spa_error_codes"></a> [spa\_error\_codes](#input\_spa\_error\_codes) | Códigos de error que se sirven como /index.html con 200 (alternativa antigua a spa\_routing). Desaconsejado: es una configuración de toda la distribución y convierte en 200 los bloqueos del WAF y los 403/404 del origen de API. Por defecto ninguno. | `list(number)` | `[]` | no |
| <a name="input_spa_routing"></a> [spa\_routing](#input\_spa\_routing) | Enrutado de la aplicación de una sola página con una CloudFront Function en el comportamiento por defecto: las rutas sin extensión se sirven con /index.html. No toca los errores (403 del WAF, respuestas de la API). | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_web_acl_arn"></a> [web\_acl\_arn](#input\_web\_acl\_arn) | ARN del Web ACL de WAF (scope CLOUDFRONT). null con un plan flat-rate que lo incluye. | `string` | `null` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Zona de Route 53 donde crear los registros A/AAAA (alias) hacia la distribución. null = el DNS se gestiona fuera. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN del bucket del sitio. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Nombre del bucket donde el pipeline sube el sitio. |
| <a name="output_cloudfront_read_policy_statement"></a> [cloudfront\_read\_policy\_statement](#output\_cloudfront\_read\_policy\_statement) | Declaración de la política del bucket que da lectura a la distribución (OAC), para auditoría. |
| <a name="output_distribution_arn"></a> [distribution\_arn](#output\_distribution\_arn) | ARN de la distribución. |
| <a name="output_distribution_domain_name"></a> [distribution\_domain\_name](#output\_distribution\_domain\_name) | Dominio *.cloudfront.net de la distribución. |
| <a name="output_distribution_id"></a> [distribution\_id](#output\_distribution\_id) | ID de la distribución (para invalidaciones tras desplegar). |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN de la CMK del bucket (propia o la aportada). El pipeline de despliegue necesita kms:GenerateDataKey/Encrypt sobre ella. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Bucket privado, solo CloudFront.** El bucket (módulo `s3-bucket`, `purpose = "static-site"`) bloquea todo acceso público y su política da `s3:GetObject` únicamente a `cloudfront.amazonaws.com` con `AWS:SourceArn` igual al ARN **exacto** de la distribución (OAC con `signing_behavior = "always"`, SigV4). Un acceso directo al bucket devuelve 403.
- **SSE-KMS.** Si no aportas `kms_key_arn`, el módulo crea una CMK propia cuya key policy permite a las distribuciones de CloudFront **de la cuenta** (`ArnLike aws:SourceArn …:distribution/*`) descifrar los objetos. No puede citar la distribución concreta: la distribución depende del bucket y el bucket de la clave, lo que formaría un ciclo. Si aportas tu clave, debe conceder ese permiso. El pipeline que sube el sitio necesita `kms:GenerateDataKey` sobre `kms_key_arn` (output).
- **Respuestas del sitio:** `index.html` como objeto raíz, `CachingOptimized`, solo métodos de lectura, compresión, `redirect-to-https`, `TLSv1.2_2021`, HTTP/2+3 y la misma política de cabeceras de seguridad que `cloudfront-vpc-origin` (módulo `security-headers`).
- **SPA con CloudFront Function (`spa_routing`, por defecto activado).** Una función `viewer-request` (`cloudfront-js-2.0`, `functions/spa-routing.js`) del comportamiento por defecto sirve `/index.html` para las rutas sin extensión. No se usan respuestas de error personalizadas: son de toda la distribución y convertían en 200 con HTML los bloqueos del WAF (403) y los 403/404 de `/api/*` (encontrado en el E2E del 2026-10-19: una SQLi bloqueada devolvía 200). `spa_error_codes` sigue disponible como opción explícita, desaconsejada.
- **Origen de API opcional (`api`)** en `path_pattern` (por defecto `/api/*`): `https-only` con TLSv1.2, sin caché, todos los métodos y `AllViewerExceptHostHeader` (aquí **no** se reenvía el `Host`: el endpoint de API Gateway tiene certificado de AWS para su propio nombre; ADR 0007).
- **Protección del origen de API (`api_origin_verify_secret`):** CloudFront añade `x-origin-verify` y el origen debe rechazar lo que no la lleve (WAF regional con `waf-web-acl` y `origin_verify` para REST API; middleware en la Lambda para HTTP API, que no admite WAF). El valor queda en el estado (cifrado por el bloque `encryption`) y es legible en la configuración de CloudFront: es un token de verificación rotable, no una credencial de datos (ADR 0010). Rotación trimestral por runbook.
- **Logs de acceso** con logging estándar v2 (sin ACL), igual que `cloudfront-vpc-origin`; el bucket debe autorizar a `delivery.logs.amazonaws.com`.

### Cómo se verificó

- 22 tests unitarios con `mock_provider`, que además comprueban que no hay ciclo de dependencias entre la política del bucket (que cita el ARN de la distribución) y la distribución (que depende del bucket). Los ejemplos validan.
- No se planificó contra AWS real porque el módulo usa data sources de la cuenta.
- **Pendiente en sandbox:** acceder al bucket directamente da 403; el sitio sirve con HSTS y TLS 1.2+; `/api/*` llega al origen con la cabecera; el pipeline puede escribir con la CMK.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
