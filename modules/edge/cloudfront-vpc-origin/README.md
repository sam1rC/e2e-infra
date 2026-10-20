# cloudfront-vpc-origin

Distribución de CloudFront con un ALB interno como origen privado (VPC origin), TLS de extremo a extremo, política de cabeceras de seguridad, WAF opcional, caché de estáticos y alias en Route 53.

## Uso

```hcl
# Instanciar con el provider de us-east-1 (logs de acceso y certificado del viewer)
module "cloudfront" {
  source    = "../../modules/edge/cloudfront-vpc-origin"
  providers = { aws = aws.us_east_1 }

  project     = "acme"
  environment = "prod"

  vpc_id                     = module.vpc.vpc_id
  alb_arn                    = module.alb.alb_arn
  alb_dns_name               = module.alb.alb_dns_name
  alb_security_group_id      = module.alb.security_group_id
  domain_names               = ["app.cliente.com"]
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

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_vpc_origin.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_vpc_origin) | resource |
| [aws_cloudwatch_log_delivery.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery_destination.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_source.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |
| [aws_route53_record.alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_vpc_security_group_ingress_rule.alb_from_cloudfront_prefix_list](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_from_cloudfront_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_cloudfront_cache_policy.caching_disabled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_cache_policy.caching_optimized](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_origin_request_policy.all_viewer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_origin_request_policy) | data source |
| [aws_ec2_managed_prefix_list.cloudfront_origin_facing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_managed_prefix_list) | data source |
| [aws_security_group.cloudfront_vpc_origins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_logs_enabled"></a> [access\_logs\_enabled](#input\_access\_logs\_enabled) | Activa los logs de acceso. Indícalo (true) cuando log\_bucket\_arn se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crean los recursos de logging. null = activado si log\_bucket\_arn no es null. | `bool` | `null` | no |
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | Certificado ACM del viewer (debe estar en us-east-1 y emitido). | `string` | n/a | yes |
| <a name="input_alb_arn"></a> [alb\_arn](#input\_alb\_arn) | ARN del ALB interno que actúa de origen. | `string` | n/a | yes |
| <a name="input_alb_dns_name"></a> [alb\_dns\_name](#input\_alb\_dns\_name) | Nombre DNS del ALB interno (dominio del origen). Con https-only CloudFront valida el certificado contra el Host reenviado, no contra este nombre (ADR 0007). | `string` | n/a | yes |
| <a name="input_alb_ingress_source"></a> [alb\_ingress\_source](#input\_alb\_ingress\_source) | Origen de la regla de entrada del ALB: cloudfront\_managed\_sg (SG CloudFront-VPCOrigins-Service-SG gestionado por AWS, más restrictivo), cloudfront\_prefix\_list (lista de prefijos origin-facing de CloudFront, respaldo) o none (la regla la crea quien llama: el módulo usa el provider de us-east-1 y el ALB está en otra región). | `string` | `"cloudfront_managed_sg"` | no |
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | Security group del ALB al que se añade la regla de entrada desde CloudFront. | `string` | n/a | yes |
| <a name="input_domain_names"></a> [domain\_names](#input\_domain\_names) | Nombres de dominio públicos (alias) de la distribución. El certificado debe cubrirlos. | `list(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_log_bucket_arn"></a> [log\_bucket\_arn](#input\_log\_bucket\_arn) | Bucket S3 para los logs de acceso (logging estándar v2, sin ACL). La entrega escribe en AWSLogs/<cuenta>/CloudFront/<log\_prefix>/...: su política debe permitir s3:PutObject en AWSLogs/<cuenta>/CloudFront/* a delivery.logs.amazonaws.com con aws:SourceAccount y aws:SourceArn del delivery source <project>-<environment>-cloudfront (si falta, CloudWatch Logs añade su propia declaración y el siguiente apply la borraría). null = sin logs. | `string` | `null` | no |
| <a name="input_log_prefix"></a> [log\_prefix](#input\_log\_prefix) | Prefijo de los logs dentro del bucket. | `string` | `"cloudfront"` | no |
| <a name="input_origin_read_timeout_seconds"></a> [origin\_read\_timeout\_seconds](#input\_origin\_read\_timeout\_seconds) | Segundos que CloudFront espera la respuesta del ALB (hasta 60 sin subir la cuota). | `number` | `30` | no |
| <a name="input_price_class"></a> [price\_class](#input\_price\_class) | Clase de precio de la distribución. | `string` | `"PriceClass_100"` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_response_headers_policy_id"></a> [response\_headers\_policy\_id](#input\_response\_headers\_policy\_id) | ID de la response headers policy de seguridad (módulo security-headers). | `string` | n/a | yes |
| <a name="input_static_path_patterns"></a> [static\_path\_patterns](#input\_static\_path\_patterns) | Patrones de ruta servidos con caché (CachingOptimized y compresión). El orden es el de precedencia. | `list(string)` | <pre>[<br/>  "/static/*",<br/>  "/assets/*"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID de la VPC del ALB interno (para localizar el security group gestionado de los VPC origins). | `string` | n/a | yes |
| <a name="input_web_acl_arn"></a> [web\_acl\_arn](#input\_web\_acl\_arn) | ARN del Web ACL de WAF (scope CLOUDFRONT). null con un plan flat-rate que lo incluye. | `string` | `null` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Zona de Route 53 donde crear los registros A/AAAA (alias) hacia la distribución. null = el DNS se gestiona fuera. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_distribution_arn"></a> [distribution\_arn](#output\_distribution\_arn) | ARN de la distribución. |
| <a name="output_distribution_domain_name"></a> [distribution\_domain\_name](#output\_distribution\_domain\_name) | Dominio *.cloudfront.net de la distribución. |
| <a name="output_distribution_id"></a> [distribution\_id](#output\_distribution\_id) | ID de la distribución. |
| <a name="output_vpc_origin_id"></a> [vpc\_origin\_id](#output\_vpc\_origin\_id) | ID del VPC origin. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **El ALB no es público.** CloudFront llega a él por un *VPC origin* (`https-only`, TLSv1.2): el ALB es interno, sin IP pública, y solo admite 443 desde el security group `CloudFront-VPCOrigins-Service-SG` que AWS crea al crear el VPC origin (`alb_ingress_source = "cloudfront_managed_sg"`), sin ningún CIDR. El respaldo `cloudfront_prefix_list` usa la lista de prefijos *origin-facing* de CloudFront (más amplia: cualquier distribución de CloudFront puede llegar al ALB). **No edites ni crees un SG con ese prefijo de nombre.** La VPC necesita un Internet Gateway aunque no haya subredes públicas (`create_internet_gateway = true` en `network/vpc`).
- **TLS hasta el origen (ADR 0007):** el comportamiento por defecto reenvía el `Host` del visitante (`Managed-AllViewer`, nunca `AllViewerExceptHostHeader`) y el listener HTTPS del ALB debe usar un **certificado ACM regional del mismo dominio público** (segunda instancia de `acm-certificate` con el provider regional). Si no coincide, CloudFront devuelve 502.
- **Viewer:** `redirect-to-https`, `TLSv1.2_2021`, SNI, HTTP/2 y HTTP/3, IPv6, certificado de us-east-1, política de cabeceras de seguridad (módulo `security-headers`) y Web ACL de WAF opcional (`web_acl_arn`; null con un plan flat-rate que lo incluye).
- **Caché:** la aplicación y la API van sin caché (`Managed-CachingDisabled`) y con todos los métodos; `static_path_patterns` (`/static/*` y `/assets/*`) usan `Managed-CachingOptimized`, compresión y solo métodos de lectura. Las políticas gestionadas se resuelven por nombre con data sources, sin IDs en el código. El orden de la lista es el de precedencia.
- **Logs de acceso (`log_bucket_arn`)** con el *logging estándar v2* (entrega CloudWatch → S3), que no usa ACL y por eso es compatible con buckets `BucketOwnerEnforced`. El plan decía "logging estándar" a secas; el clásico exige ACL en el bucket, que el módulo `s3-bucket` prohíbe. Los recursos de entrega deben crearse en us-east-1, y el bucket debe autorizar a `delivery.logs.amazonaws.com` (ver `examples/complete`). Se usa SSE-S3 en ese bucket.
- **DNS:** con `zone_id`, registros A y AAAA (alias) por dominio; sin él, el DNS se gestiona fuera.
- Los *timeouts* del VPC origin son de 20 minutos (la creación puede tardar).

### Cómo se verificó

- 18 tests unitarios con `mock_provider`. El mock da el mismo ID a las dos políticas de caché gestionadas, así que se comprueba la referencia y el nombre de cada política, no el ID.
- Los dos ejemplos validan (ALB interno + listener HTTPS + WAF + cabeceras de seguridad + este módulo). No se planificó contra AWS real porque el módulo usa data sources.
- **Pendiente en sandbox** (criterios de aceptación de la fase): `curl -I https://<dominio>` devuelve HSTS y TLS 1.2+; el DNS del ALB no resuelve a una IP pública; el VPC origin se crea con el provider 6.67.0 (regresión conocida en 6.17); HTTPS 200 de extremo a extremo con `https-only`.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
